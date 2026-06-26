import XCTest
@testable import EchoDeckBuilder

final class LocalProcessRunnerTests: XCTestCase {
    func testRunCancelsLongRunningProcessPromptly() async throws {
        let runner = LocalProcessRunner()
        let startedAt = Date()

        let task = Task {
            try await runner.run(ProcessInvocation(
                executable: "/bin/sh",
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                standardInput: "",
                timeoutSeconds: 30
            ))
        }

        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testRunReportsCancellationWhenProcessExitsAfterTerminate() async throws {
        let runner = LocalProcessRunner()

        let task = Task {
            try await runner.run(ProcessInvocation(
                executable: "/bin/sleep",
                arguments: ["30"],
                standardInput: "",
                timeoutSeconds: 30
            ))
        }

        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {
            XCTAssertTrue(task.isCancelled)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testRunTimesOutForLongRunningProcess() async throws {
        let runner = LocalProcessRunner()
        let startedAt = Date()

        do {
            _ = try await runner.run(ProcessInvocation(
                executable: "/bin/sh",
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                standardInput: "",
                timeoutSeconds: 0.2
            ))
            XCTFail("Expected the process to time out.")
        } catch let error as LocalProcessRunnerError {
            switch error {
            case .timedOut(let timeoutSeconds):
                XCTAssertEqual(timeoutSeconds, 0.2, accuracy: 0.001)
            default:
                XCTFail("Expected timedOut error, got \(error).")
            }
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
    }

    func testRunTimesOutWhenChildDoesNotReadLargeStandardInput() async throws {
        let runner = LocalProcessRunner()
        let startedAt = Date()
        let largeInput = String(repeating: "large prompt body\n", count: 65_536)

        do {
            _ = try await runner.run(ProcessInvocation(
                executable: "/bin/sh",
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                standardInput: largeInput,
                timeoutSeconds: 0.2
            ))
            XCTFail("Expected the process to time out.")
        } catch let error as LocalProcessRunnerError {
            switch error {
            case .timedOut(let timeoutSeconds):
                XCTAssertEqual(timeoutSeconds, 0.2, accuracy: 0.001)
            default:
                XCTFail("Expected timedOut error, got \(error).")
            }
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
    }

    func testTimeoutTerminatesChildProcessGroup() async throws {
        let runner = LocalProcessRunner()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EchoDeckBuilder-ProcessGroup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let childPIDFile = directory.appending(path: "child.pid")

        do {
            _ = try await runner.run(ProcessInvocation(
                executable: "/bin/sh",
                arguments: [
                    "-c",
                    "trap '' TERM; /bin/sh -c 'trap \"\" TERM; while :; do sleep 1; done' & echo $! > '\(childPIDFile.path)'; while :; do sleep 1; done"
                ],
                standardInput: "",
                timeoutSeconds: 0.2
            ))
            XCTFail("Expected the process to time out.")
        } catch LocalProcessRunnerError.timedOut {
            let childPID = try await waitForChildPID(at: childPIDFile)
            try await assertProcessExits(childPID)
        } catch {
            XCTFail("Expected timedOut error, got \(error).")
        }
    }

    func testRunCleansBackgroundChildBeforeDrainingOutput() async throws {
        let runner = LocalProcessRunner()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EchoDeckBuilder-BackgroundChild-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let childPIDFile = directory.appending(path: "child.pid")
        let startedAt = Date()

        let result = try await runner.run(ProcessInvocation(
            executable: "/bin/sh",
            arguments: [
                "-c",
                "/bin/sh -c 'trap \"\" TERM; while :; do sleep 1; done' & echo $! > '\(childPIDFile.path)'; exit 0"
            ],
            standardInput: "",
            timeoutSeconds: 5
        ))

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
        XCTAssertEqual(result.terminationStatus, 0)
        let childPID = try await waitForChildPID(at: childPIDFile)
        try await assertProcessExits(childPID)
    }

    func testRunCapturesLargeStdoutWithoutDeadlock() async throws {
        let runner = LocalProcessRunner()
        let chunk = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let repetitions = 2_048
        let result = try await runner.run(ProcessInvocation(
            executable: "/bin/sh",
            arguments: ["-c", "i=0; while [ \"$i\" -lt \(repetitions) ]; do printf '\(chunk)'; i=$((i + 1)); done"],
            standardInput: "",
            timeoutSeconds: 5
        ))

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertEqual(result.standardOutput, String(repeating: chunk, count: repetitions))
    }

    private func waitForChildPID(at url: URL) async throws -> pid_t {
        for _ in 0..<20 {
            if let text = try? String(contentsOf: url, encoding: .utf8),
               let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return pid
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("Timed out waiting for child PID file.")
        return 0
    }

    private func assertProcessExits(_ pid: pid_t) async throws {
        for _ in 0..<20 {
            if kill(pid, 0) == -1, errno == ESRCH {
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Expected child process \(pid) to be terminated with its process group.")
    }
}
