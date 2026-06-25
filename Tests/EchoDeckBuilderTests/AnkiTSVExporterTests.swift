import XCTest
@testable import EchoDeckBuilder

final class AnkiTSVExporterTests: XCTestCase {
    func testExportsEmptyStringWhenNoCardsAreAccepted() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let card = DeckCard(
            sectionID: UUID(),
            frontText: "Front text",
            backText: "Back text",
            kind: .basic,
            sourceAnchor: anchor
        )

        let output = AnkiTSVExporter().export(cards: [card])

        XCTAssertEqual(output, "")
    }

    func testExportsAcceptedCardsAsTabSeparatedRows() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b2"))
        let card = DeckCard(
            sectionID: UUID(),
            frontText: "Front text",
            backText: "Back text",
            kind: .basic,
            tags: ["tag one", "tag-two"],
            sourceAnchor: anchor,
            reviewState: .accepted
        )

        let output = AnkiTSVExporter().export(cards: [card])

        XCTAssertEqual(output, "Front text\tBack text\ttag_one tag-two\ts1-b2\n")
    }
}
