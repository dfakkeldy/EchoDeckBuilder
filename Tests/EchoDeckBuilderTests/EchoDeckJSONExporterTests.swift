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

    func testExportSummaryCountsReviewStatesAndAnchors() throws {
        let anchor1 = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let anchor2 = try XCTUnwrap(SourceAnchor(suffix: "s1-b2"))
        let anchor3 = try XCTUnwrap(SourceAnchor(suffix: "s1-b3"))
        let accepted = DeckCard(
            sectionID: UUID(),
            frontText: "Accepted",
            backText: "Exported",
            kind: .basic,
            sourceAnchor: anchor1,
            reviewState: .accepted
        )
        let draft = DeckCard(
            sectionID: UUID(),
            frontText: "Draft",
            backText: "Not exported",
            kind: .basic,
            sourceAnchor: anchor2,
            reviewState: .draft
        )
        let rejected = DeckCard(
            sectionID: UUID(),
            frontText: "Rejected",
            backText: "Not exported",
            kind: .basic,
            sourceAnchor: anchor2,
            reviewState: .rejected
        )
        let accepted2 = DeckCard(
            sectionID: UUID(),
            frontText: "Accepted again",
            backText: "Also exported",
            kind: .basic,
            sourceAnchor: anchor3,
            reviewState: .accepted
        )

        let summary = EchoDeckJSONExporter().summary(for: [accepted, draft, rejected, accepted2])

        XCTAssertEqual(summary.totalCards, 4)
        XCTAssertEqual(summary.acceptedCount, 2)
        XCTAssertEqual(summary.draftCount, 1)
        XCTAssertEqual(summary.rejectedCount, 1)
        XCTAssertEqual(summary.exportedCount, 2)
        XCTAssertEqual(summary.sourceAnchoredCount, 2)
    }
}
