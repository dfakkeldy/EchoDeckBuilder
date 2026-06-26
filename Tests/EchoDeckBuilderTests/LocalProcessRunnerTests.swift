import XCTest
@testable import EchoDeckBuilder

final class LocalProcessRunnerTests: XCTestCase {
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
}
