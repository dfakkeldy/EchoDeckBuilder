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

            try process.run()
            if let inputData = invocation.standardInput.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(inputData)
            }
            inputPipe.fileHandleForWriting.closeFile()

            let deadline = Date.now.addingTimeInterval(invocation.timeoutSeconds)
            while process.isRunning {
                if Date.now >= deadline {
                    process.terminate()
                    process.waitUntilExit()
                    throw LocalProcessRunnerError.timedOut(invocation.timeoutSeconds)
                }
                try await Task.sleep(for: .milliseconds(50))
            }

            let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
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
}
