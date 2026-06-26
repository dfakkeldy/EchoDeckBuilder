import Darwin
import Dispatch
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
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: invocation.executable)
            process.arguments = invocation.arguments
            process.currentDirectoryURL = invocation.workingDirectory

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let stdoutBuffer = LockedDataBuffer()
            let stderrBuffer = LockedDataBuffer()
            let terminationSemaphore = DispatchSemaphore(value: 0)

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard data.isEmpty == false else {
                    handle.readabilityHandler = nil
                    return
                }
                stdoutBuffer.append(data)
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard data.isEmpty == false else {
                    handle.readabilityHandler = nil
                    return
                }
                stderrBuffer.append(data)
            }

            process.terminationHandler = { _ in
                terminationSemaphore.signal()
            }

            try process.run()
            if let inputData = invocation.standardInput.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(inputData)
            }
            inputPipe.fileHandleForWriting.closeFile()

            let didTerminate = waitForTermination(
                semaphore: terminationSemaphore,
                timeoutSeconds: invocation.timeoutSeconds
            )
            guard didTerminate == .success else {
                cleanupAfterTimeout(
                    process: process,
                    terminationSemaphore: terminationSemaphore,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe
                )
                throw LocalProcessRunnerError.timedOut(invocation.timeoutSeconds)
            }

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            stdoutBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
            stderrBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

            let stdoutData = stdoutBuffer.data
            let stderrData = stderrBuffer.data
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
        }.value
    }

    private func cleanupAfterTimeout(
        process: Process,
        terminationSemaphore: DispatchSemaphore,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) {
        process.terminate()
        if terminationSemaphore.wait(timeout: .now() + .milliseconds(250)) == .success {
            closeReaders(outputPipe: outputPipe, errorPipe: errorPipe)
            return
        }

        let processIdentifier = process.processIdentifier
        if processIdentifier > 0 {
            kill(processIdentifier, SIGKILL)
        }
        _ = terminationSemaphore.wait(timeout: .now() + .seconds(1))
        closeReaders(outputPipe: outputPipe, errorPipe: errorPipe)
    }

    private func waitForTermination(
        semaphore: DispatchSemaphore,
        timeoutSeconds: TimeInterval
    ) -> DispatchTimeoutResult {
        semaphore.wait(timeout: .now() + timeoutSeconds)
    }

    private func closeReaders(outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()
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
