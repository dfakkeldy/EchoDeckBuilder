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

    func testAcceptedCardsDoNotIncludeVisualMetadata() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s4-b8"))
        let visual = CardVisual(
            priority: .high,
            imagePrompt: "A lighthouse glowing over a stormy sea",
            altText: "Lighthouse"
        )

        let card = DeckCard(
            sectionID: UUID(),
            frontText: "Front",
            backText: "Back",
            kind: .basic,
            sourceAnchor: anchor,
            reviewState: .accepted,
            visual: visual
        )

        let data = try EchoDeckJSONExporter().export(
            deckName: "Deck",
            targetMediaID: "book",
            cards: [card]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
        let firstCard = try XCTUnwrap(cards.first)

        XCTAssertNil(firstCard["visual"] as? [String: Any])
        XCTAssertNil(firstCard["imagePrompt"] as? String)
        XCTAssertNil(firstCard["priority"] as? String)
        XCTAssertNil(firstCard["altText"] as? String)
        XCTAssertEqual(firstCard["sourceAnchor"] as? String, "s4-b8")
    }
}
