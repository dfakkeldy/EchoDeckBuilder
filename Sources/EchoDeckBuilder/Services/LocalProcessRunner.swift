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

    public var errorDescription: String? {
        switch self {
        case .nonZeroExit(let status, let stderr):
            "Process exited with status \(status): \(stderr)"
        case .invalidOutputEncoding:
            "Process output was not valid UTF-8."
        case .timedOut(let timeoutSeconds):
            "Process timed out after \(timeoutSeconds) seconds."
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

private final class ProcessExecution: @unchecked Sendable {
    private let invocation: ProcessInvocation
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let stdoutBuffer = LockedDataBuffer()
    private let stderrBuffer = LockedDataBuffer()
    private let state = ProcessExecutionState()

    init(invocation: ProcessInvocation) {
        self.invocation = invocation
        configureProcess()
    }

    func run() async throws -> ProcessResult {
        try launch()
        defer { stopMonitoringOutput() }

        let deadline = ContinuousClock.now + .seconds(invocation.timeoutSeconds)
        do {
            while process.isRunning {
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
            terminationStatus: process.terminationStatus
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

    private func configureProcess() {
        process.executableURL = URL(fileURLWithPath: invocation.executable)
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.workingDirectory
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

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

        process.terminationHandler = { [state] _ in
            state.markTerminated()
        }
    }

    private func launch() throws {
        try process.run()
        state.markLaunched()

        if let inputData = invocation.standardInput.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
        }
        inputPipe.fileHandleForWriting.closeFile()

        if state.isCancelled {
            terminateProcess()
        }
    }

    private func waitForTermination() async {
        if state.isTerminated {
            return
        }

        await withCheckedContinuation { continuation in
            if state.storeTerminationContinuation(continuation) == false {
                continuation.resume()
            }
        }
    }

    private func terminateProcess() {
        guard state.canTerminate else {
            return
        }

        if process.isRunning {
            process.terminate()
        }

        let processIdentifier = process.processIdentifier
        guard processIdentifier > 0 else {
            return
        }

        let deadline = ContinuousClock.now + .milliseconds(250)
        while state.isTerminated == false, ContinuousClock.now < deadline {
            usleep(10_000)
        }

        guard state.isTerminated == false else {
            return
        }

        _ = kill(processIdentifier, SIGKILL)
    }

    private func stopMonitoringOutput() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
    }

    private func collectedOutput(from pipe: Pipe, buffer: LockedDataBuffer) -> Data {
        buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
        return buffer.data
    }
}

private final class ProcessExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var didLaunch = false
    private var didCancel = false
    private var didTerminate = false
    private var terminationContinuation: CheckedContinuation<Void, Never>?

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

    var canTerminate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didLaunch && didTerminate == false
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
        let continuation: CheckedContinuation<Void, Never>?
        lock.lock()
        didTerminate = true
        continuation = terminationContinuation
        terminationContinuation = nil
        lock.unlock()

        continuation?.resume()
    }

    func storeTerminationContinuation(_ continuation: CheckedContinuation<Void, Never>) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard didTerminate == false else {
            return false
        }

        terminationContinuation = continuation
        return true
    }
}
