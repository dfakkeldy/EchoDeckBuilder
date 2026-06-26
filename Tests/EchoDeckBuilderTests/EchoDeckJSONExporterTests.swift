import XCTest
@testable import EchoDeckBuilder

final class EchoDeckJSONExporterTests: XCTestCase {
    func testExportsAcceptedCardsWithSourceAnchor() throws {
        let sectionID = UUID()
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s4-b12"))
        let card = DeckCard(
            sectionID: sectionID,
            frontText: "What does the chapter argue?",
            backText: "Constraints shape behavior.",
            kind: .basic,
            tags: ["chapter-4"],
            sourceAnchor: anchor,
            reviewState: .accepted
        )

        let data = try EchoDeckJSONExporter().export(
            deckName: "Chapter 4 Review",
            targetMediaID: "file:///Books/Example",
            cards: [card]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])

        XCTAssertEqual(object["deckName"] as? String, "Chapter 4 Review")
        XCTAssertEqual(object["targetMediaID"] as? String, "file:///Books/Example")
        XCTAssertEqual(cards.first?["sourceAnchor"] as? String, "s4-b12")
        XCTAssertNil(cards.first?["source"])
        XCTAssertNil(cards.first?["echoBlockID"])
    }

    func testRejectedCardsAreNotExported() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let rejected = DeckCard(
            sectionID: UUID(),
            frontText: "Rejected?",
            backText: "No export.",
            kind: .basic,
            sourceAnchor: anchor,
            reviewState: .rejected
        )

        let data = try EchoDeckJSONExporter().export(
            deckName: "Deck",
            targetMediaID: "book",
            cards: [rejected]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
        XCTAssertEqual(cards.count, 0)
    }
}
