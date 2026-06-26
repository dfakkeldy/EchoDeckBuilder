import XCTest
@testable import EchoDeckBuilder

final class EPUBContainerParserTests: XCTestCase {
    func testMalformedContainerXMLReturnsParseFailure() throws {
        let data = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container>
            <rootfiles>
                <rootfile full-path="OPS/package.opf">
            </rootfiles>
        </container>
        """.utf8)

        var receivedError: EPUBExtractionError?
        XCTAssertThrowsError(try EPUBContainerParser().packagePath(from: data)) { error in
            receivedError = error as? EPUBExtractionError
        }

        guard case let .containerParseFailed(message)? = receivedError else {
            return XCTFail("Expected containerParseFailed, got \(String(describing: receivedError))")
        }

        XCTAssertFalse(message.isEmpty)
    }
}
