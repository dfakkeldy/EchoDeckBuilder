import Darwin
import Foundation

public struct ProcessInvocation: Hashable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var standardInput: String
    public var workingDirectory: URL?
    public var timeoutSeconds: TimeInterval

    public init(
        executable: String,
        arguments: [String],
        standardInput: String,
        workingDirectory: URL? = nil,
        timeoutSeconds: TimeInterval = 120
    ) {
        self.executable = executable
        self.arguments = arguments
        self.standardInput = standardInput
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct ProcessResult: Hashable, Sendable {
    public var standardOutput: String
    public var standardError: String
    public var terminationStatus: Int32

    public init(standardOutput: String, standardError: String, terminationStatus: Int32) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.terminationStatus = terminationStatus
    }
}

public protocol ProcessRunning: Sendable {
    func run(_ invocation: ProcessInvocation) async throws -> ProcessResult
}

public enum LocalProcessRunnerError: Error, LocalizedError, Sendable {
    case nonZeroExit(Int32, String)
    case invalidOutputEncoding
    case timedOut(TimeInterval)
    case failedToLaunch(String)

    public var errorDescription: String? {
        switch self {
        case .nonZeroExit(let status, let stderr):
            "Process exited with status \(status): \(stderr)"
        case .invalidOutputEncoding:
            "Process output was not valid UTF-8."
        case .timedOut(let timeoutSeconds):
            "Process timed out after \(timeoutSeconds) seconds."
        case .failedToLaunch(let message):
            "Process failed to launch: \(message)"
        }
    }
}

public struct LocalProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ invocation: ProcessInvocation) async throws -> ProcessResult {
        let execution = ProcessExecution(invocation: invocation)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await execution.run()
        } onCancel: {
            execution.cancel()
        }
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ chunk: Data) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class StandardInputPipe: @unchecked Sendable {
    let pipe = Pipe()

    private let input: String
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var didCloseWriting = false

    init(input: String) {
        self.input = input
        _ = fcntl(pipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
    }

    func startWriting() {
        lock.lock()
        guard task == nil, didCloseWriting == false else {
            lock.unlock()
            return
        }

        let writeTask = Task.detached(priority: .userInitiated) { [self] in
            writeInput()
        }
        task = writeTask
        lock.unlock()
    }

    func cancelWriting() {
        let taskToCancel: Task<Void, Never>?
        lock.lock()
        taskToCancel = task
        lock.unlock()

        taskToCancel?.cancel()
        closeWritingHandle()
    }

    private func writeInput() {
        defer { closeWritingHandle() }

        do {
            try Task.checkCancellation()
            guard input.isEmpty == false else {
                return
            }

            try pipe.fileHandleForWriting.write(contentsOf: Data(input.utf8))
        } catch {
            return
        }
    }

    private func closeWritingHandle() {
        lock.lock()
        guard didCloseWriting == false else {
            lock.unlock()
            return
        }
        didCloseWriting = true
        lock.unlock()

        try? pipe.fileHandleForWriting.close()
    }

    func closeReadingHandle() {
        try? pipe.fileHandleForReading.close()
    }
}

private final class ProcessExecution: @unchecked Sendable {
    private let invocation: ProcessInvocation
    private let standardInputPipe: StandardInputPipe
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let stdoutBuffer = LockedDataBuffer()
    private let stderrBuffer = LockedDataBuffer()
    private let state = ProcessExecutionState()
    private let processLock = NSLock()
    private var processIdentifier: pid_t = 0
    private var processTerminationStatus: Int32 = 0

    init(invocation: ProcessInvocation) {
        self.invocation = invocation
        self.standardInputPipe = StandardInputPipe(input: invocation.standardInput)
        configurePipes()
    }

    func run() async throws -> ProcessResult {
        try launch()
        defer {
            standardInputPipe.cancelWriting()
            stopMonitoringOutput()
        }

        let deadline = ContinuousClock.now + .seconds(invocation.timeoutSeconds)
        do {
            while reapTerminatedProcess() == false {
                try Task.checkCancellation()
                if ContinuousClock.now >= deadline {
                    terminateProcess()
                    await waitForTermination()
                    throw LocalProcessRunnerError.timedOut(invocation.timeoutSeconds)
                }
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch is CancellationError {
            terminateProcess()
            await waitForTermination()
            throw CancellationError()
        }

        if state.isCancelled {
            throw CancellationError()
        }
        try Task.checkCancellation()

        cleanUpProcessGroupBeforeDrainingOutput()
        let stdoutData = collectedOutput(from: outputPipe, buffer: stdoutBuffer)
        let stderrData = collectedOutput(from: errorPipe, buffer: stderrBuffer)
        guard let stdout = String(data: stdoutData, encoding: .utf8),
              let stderr = String(data: stderrData, encoding: .utf8)
        else {
            throw LocalProcessRunnerError.invalidOutputEncoding
        }

        let result = ProcessResult(
            standardOutput: stdout,
            standardError: stderr,
            terminationStatus: currentTerminationStatus
        )
        guard result.terminationStatus == 0 else {
            throw LocalProcessRunnerError.nonZeroExit(result.terminationStatus, result.standardError)
        }
        return result
    }

    func cancel() {
        state.markCancelled()
        terminateProcess()
    }

    private func configurePipes() {
        outputPipe.fileHandleForReading.readabilityHandler = { [stdoutBuffer] handle in
            let data = handle.availableData
            guard data.isEmpty == false else {
                handle.readabilityHandler = nil
                return
            }
            stdoutBuffer.append(data)
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [stderrBuffer] handle in
            let data = handle.availableData
            guard data.isEmpty == false else {
                handle.readabilityHandler = nil
                return
            }
            stderrBuffer.append(data)
        }
    }

    private func launch() throws {
        var fileActions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        try checkSpawn(posix_spawn_file_actions_init(&fileActions), operation: "file actions init")
        try checkSpawn(posix_spawnattr_init(&attributes), operation: "attributes init")
        defer {
            _ = posix_spawn_file_actions_destroy(&fileActions)
            _ = posix_spawnattr_destroy(&attributes)
        }

        try configureSpawnFileActions(&fileActions)
        try configureSpawnAttributes(&attributes)

        var pid: pid_t = 0
        var cArguments = ([invocation.executable] + invocation.arguments).map { strdup($0) }
        defer {
            for argument in cArguments {
                free(argument)
            }
        }
        cArguments.append(nil)

        let spawnResult = invocation.executable.withCString { executablePath in
            cArguments.withUnsafeMutableBufferPointer { arguments in
                posix_spawn(
                    &pid,
                    executablePath,
                    &fileActions,
                    &attributes,
                    arguments.baseAddress,
                    environ
                )
            }
        }
        try checkSpawn(spawnResult, operation: "spawn \(invocation.executable)")

        processLock.lock()
        processIdentifier = pid
        processTerminationStatus = 0
        processLock.unlock()

        closeParentChildPipeEnds()
        state.markLaunched()
        standardInputPipe.startWriting()

        if state.isCancelled {
            terminateProcess()
        }
    }

    private func waitForTermination() async {
        while reapTerminatedProcess() == false {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func terminateProcess() {
        guard state.canSignalProcessGroup else {
            return
        }

        standardInputPipe.cancelWriting()

        let processIdentifier = currentProcessIdentifier
        guard processIdentifier > 0 else {
            return
        }

        sendSignal(SIGTERM, toProcessGroup: processIdentifier)
        let deadline = ContinuousClock.now + .milliseconds(250)
        while reapTerminatedProcess() == false, ContinuousClock.now < deadline {
            usleep(10_000)
        }

        sendSignal(SIGKILL, toProcessGroup: processIdentifier)
    }

    private func cleanUpProcessGroupBeforeDrainingOutput() {
        let processIdentifier = currentProcessIdentifier
        guard processIdentifier > 0 else {
            return
        }

        sendSignal(SIGTERM, toProcessGroup: processIdentifier)
        usleep(50_000)
        sendSignal(SIGKILL, toProcessGroup: processIdentifier)
        usleep(50_000)
    }

    private func stopMonitoringOutput() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
    }

    private func collectedOutput(from pipe: Pipe, buffer: LockedDataBuffer) -> Data {
        buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
        return buffer.data
    }

    private var currentProcessIdentifier: pid_t {
        processLock.lock()
        defer { processLock.unlock() }
        return processIdentifier
    }

    private var currentTerminationStatus: Int32 {
        processLock.lock()
        defer { processLock.unlock() }
        return processTerminationStatus
    }

    private func configureSpawnFileActions(_ fileActions: inout posix_spawn_file_actions_t?) throws {
        try checkSpawn(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                standardInputPipe.pipe.fileHandleForReading.fileDescriptor,
                STDIN_FILENO
            ),
            operation: "stdin dup2"
        )
        try checkSpawn(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                outputPipe.fileHandleForWriting.fileDescriptor,
                STDOUT_FILENO
            ),
            operation: "stdout dup2"
        )
        try checkSpawn(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                errorPipe.fileHandleForWriting.fileDescriptor,
                STDERR_FILENO
            ),
            operation: "stderr dup2"
        )

        let childPipeFileDescriptors = [
            standardInputPipe.pipe.fileHandleForReading.fileDescriptor,
            standardInputPipe.pipe.fileHandleForWriting.fileDescriptor,
            outputPipe.fileHandleForReading.fileDescriptor,
            outputPipe.fileHandleForWriting.fileDescriptor,
            errorPipe.fileHandleForReading.fileDescriptor,
            errorPipe.fileHandleForWriting.fileDescriptor
        ]
        for fileDescriptor in childPipeFileDescriptors {
            try checkSpawn(
                posix_spawn_file_actions_addclose(&fileActions, fileDescriptor),
                operation: "close fd \(fileDescriptor)"
            )
        }

        if let workingDirectory = invocation.workingDirectory {
            try workingDirectory.path.withCString { path in
                if #available(macOS 26.0, *) {
                    try checkSpawn(
                        posix_spawn_file_actions_addchdir(&fileActions, path),
                        operation: "chdir \(workingDirectory.path)"
                    )
                } else {
                    try checkSpawn(
                        posix_spawn_file_actions_addchdir_np(&fileActions, path),
                        operation: "chdir \(workingDirectory.path)"
                    )
                }
            }
        }
    }

    private func configureSpawnAttributes(_ attributes: inout posix_spawnattr_t?) throws {
        try checkSpawn(
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)),
            operation: "set process group flag"
        )
        try checkSpawn(
            posix_spawnattr_setpgroup(&attributes, 0),
            operation: "set process group"
        )
    }

    private func closeParentChildPipeEnds() {
        standardInputPipe.closeReadingHandle()
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()
    }

    private func reapTerminatedProcess() -> Bool {
        if state.isTerminated {
            return true
        }

        let processIdentifier = currentProcessIdentifier
        guard processIdentifier > 0 else {
            return false
        }

        var waitStatus: Int32 = 0
        let result = waitpid(processIdentifier, &waitStatus, WNOHANG)
        if result == processIdentifier {
            processLock.lock()
            processTerminationStatus = normalizedTerminationStatus(from: waitStatus)
            processLock.unlock()
            state.markTerminated()
            return true
        }

        if result == -1, errno == ECHILD {
            state.markTerminated()
            return true
        }

        return false
    }

    private func sendSignal(_ signal: Int32, toProcessGroup processIdentifier: pid_t) {
        let groupResult = kill(-processIdentifier, signal)
        if groupResult == -1, errno == ESRCH {
            _ = kill(processIdentifier, signal)
        }
    }

    private func normalizedTerminationStatus(from waitStatus: Int32) -> Int32 {
        let status = waitStatus & 0x7f
        if status == 0 {
            return (waitStatus >> 8) & 0xff
        }
        if status != 0x7f {
            return status
        }
        return waitStatus
    }

    private func checkSpawn(_ status: Int32, operation: String) throws {
        guard status == 0 else {
            throw LocalProcessRunnerError.failedToLaunch("\(operation): \(String(cString: strerror(status)))")
        }
    }
}

private final class ProcessExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var didLaunch = false
    private var didCancel = false
    private var didTerminate = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didCancel
    }

    var isTerminated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didTerminate
    }

    var canSignalProcessGroup: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didLaunch
    }

    func markLaunched() {
        lock.lock()
        didLaunch = true
        lock.unlock()
    }

    func markCancelled() {
        lock.lock()
        didCancel = true
        lock.unlock()
    }

    func markTerminated() {
        lock.lock()
        didTerminate = true
        lock.unlock()
    }
}
