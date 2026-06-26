import XCTest
@testable import EchoDeckBuilder

final class GeneratedCardDraftTests: XCTestCase {
    func testDraftMapsToDraftDeckCardWithSourceAnchorPreserved() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Context",
            text: "Context helps generated cards stay grounded.",
            anchor: anchor
        )
        let draft = GeneratedCardDraft(
            frontText: "Why should generated cards stay grounded?",
            backText: "Grounding keeps the card tied to the supplied source instead of model guesses.",
            kind: .basic,
            tags: [" Context ", "ai"]
        )

        let card = try XCTUnwrap(GeneratedCardDraftMapper.deckCard(from: draft, section: section))

        XCTAssertEqual(card.sectionID, section.id)
        XCTAssertEqual(card.sourceAnchor, anchor)
        XCTAssertEqual(card.reviewState, .draft)
        XCTAssertEqual(card.frontText, "Why should generated cards stay grounded?")
        XCTAssertEqual(card.backText, "Grounding keeps the card tied to the supplied source instead of model guesses.")
        XCTAssertEqual(card.kind, .basic)
        XCTAssertEqual(card.tags, ["generated", "foundation-models", "Context", "ai"])
    }

    func testDraftMapperRejectsEmptyFrontOrBack() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "Short text.",
            anchor: anchor
        )

        XCTAssertNil(
            GeneratedCardDraftMapper.deckCard(
                from: GeneratedCardDraft(frontText: " ", backText: "Answer", kind: .basic, tags: []),
                section: section
            )
        )
        XCTAssertNil(
            GeneratedCardDraftMapper.deckCard(
                from: GeneratedCardDraft(frontText: "Question", backText: " ", kind: .basic, tags: []),
                section: section
            )
        )
    }

    func testDraftMapperDeduplicatesDefaultTags() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b2"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 2,
            heading: "Intro",
            text: "Short text.",
            anchor: anchor
        )
        let draft = GeneratedCardDraft(
            frontText: "Front",
            backText: "Back",
            kind: .cloze,
            tags: ["generated", "foundation-models", "generated", "deck"]
        )

        let card = try XCTUnwrap(GeneratedCardDraftMapper.deckCard(from: draft, section: section))

        XCTAssertEqual(card.kind, .cloze)
        XCTAssertEqual(card.tags, ["generated", "foundation-models", "deck"])
    }
}
