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
        XCTAssertEqual(cards.first?["triggerTiming"] as? String, "manualOnly")
        XCTAssertNil(cards.first?["startTime"])
        XCTAssertNil(cards.first?["endTime"])
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

    func testExportsAcceptedGeneratedDraftCardsAsAnchorOnly() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s3-b7"))
        let section = BookSection(
            spineIndex: 3,
            blockIndex: 7,
            heading: "Signals",
            text: "Signals help the review system stay tied to the imported source.",
            anchor: anchor
        )
        let draft = GeneratedCardDraft(
            frontText: "Why keep the generated card tied to the imported source?",
            backText: "It preserves traceability without exporting the full source text.",
            kind: .basic,
            tags: ["signals"]
        )
        var card = try XCTUnwrap(GeneratedCardDraftMapper.deckCard(from: draft, section: section))
        card.reviewState = .accepted

        let data = try EchoDeckJSONExporter().export(
            deckName: "Signals",
            targetMediaID: "echo://signals",
            cards: [card]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?["sourceAnchor"] as? String, "s3-b7")
        XCTAssertNil(cards.first?["source"])
        XCTAssertNil(cards.first?["echoBlockID"])
    }
}
