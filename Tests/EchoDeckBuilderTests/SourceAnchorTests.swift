import XCTest
@testable import EchoDeckBuilder

final class SourceAnchorTests: XCTestCase {
    func testCanonicalSuffixIsAccepted() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("s4-b12"))
        XCTAssertEqual(anchor.suffix, "s4-b12")
    }

    func testLegacyFullBlockIDStripsToPortableSuffix() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("epub-old-book-id-s4-b12"))
        XCTAssertEqual(anchor.suffix, "s4-b12")
    }

    func testMalformedAnchorIsRejected() {
        XCTAssertNil(SourceAnchor.parse("chapter-4-block-12"))
        XCTAssertNil(SourceAnchor.parse("s4"))
        XCTAssertNil(SourceAnchor.parse("b12"))
    }

    func testLocalFullIDUsesTargetMediaID() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("s4-b12"))
        XCTAssertEqual(anchor.fullEchoBlockID(targetMediaID: "book-123"), "epub-book-123-s4-b12")
    }
}
