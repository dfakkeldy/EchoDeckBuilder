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

    func testExportsAcceptedCardsWithoutVisualMetadata() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b5"))
        let visual = CardVisual(
            priority: .medium,
            imagePrompt: "A red fox in winter woods",
            altText: "A fox"
        )
        let card = DeckCard(
            sectionID: UUID(),
            frontText: "Front text",
            backText: "Back text",
            kind: .basic,
            tags: ["tag one"],
            sourceAnchor: anchor,
            reviewState: .accepted,
            visual: visual
        )

        let output = AnkiTSVExporter().export(cards: [card])

        XCTAssertEqual(output, "Front text\tBack text\ttag_one\ts2-b5\n")
        XCTAssertFalse(output.contains("A red fox in winter woods"))
        XCTAssertFalse(output.contains("medium"))
    }
}
