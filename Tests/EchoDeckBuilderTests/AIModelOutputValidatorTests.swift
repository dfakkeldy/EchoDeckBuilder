import XCTest
@testable import EchoDeckBuilder

final class AIModelOutputValidatorTests: XCTestCase {
    func testValidOutputBecomesDraftDeckCards() throws {
        let section = try makeSection(suffix: "s1-b1")
        let output = AIModelOutput(
            run: .init(provider: "claude-cli", model: "default", sourceScope: "selected-book", imageMode: "prompts"),
            bookBrief: .init(
                summary: "The book explains durable strategy.",
                themes: ["strategy"],
                keyConcepts: ["anchor"],
                argumentFlow: ["define", "apply"],
                skipAreas: ["preface"]
            ),
            cards: [
                .init(
                    sourceAnchor: "s1-b1",
                    kind: "basic",
                    frontText: "What does a strategic anchor provide?",
                    backText: "A decision rule for choosing work that advances the goal.",
                    clozeText: nil,
                    tags: ["strategy"],
                    importance: 0.9,
                    confidence: 0.8,
                    rationale: "This is a central concept.",
                    visual: .init(priority: "high", imagePrompt: "A compass fixed to a book page.", altText: "A compass points from a book page toward a goal.")
                )
            ],
            warnings: ["Skipped acknowledgements."]
        )

        let result = try AIModelOutputValidator().validate(output, batchSections: [section])

        XCTAssertEqual(result.bookBrief.summary, "The book explains durable strategy.")
        XCTAssertEqual(result.cards.count, 1)
        XCTAssertEqual(result.cards[0].sectionID, section.id)
        XCTAssertEqual(result.cards[0].sourceAnchor.suffix, "s1-b1")
        XCTAssertEqual(result.cards[0].reviewState, .draft)
        XCTAssertEqual(result.cards[0].visual?.priority, .high)
        XCTAssertEqual(result.cards[0].aiMetadata?.importance, 0.9)
        XCTAssertEqual(result.cards[0].aiMetadata?.confidence, 0.8)
        XCTAssertEqual(result.cards[0].aiMetadata?.rationale, "This is a central concept.")
        XCTAssertEqual(result.runMetadata?.provider, "claude-cli")
        XCTAssertEqual(result.runMetadata?.model, "default")
        XCTAssertEqual(result.warnings.map(\.message), ["Skipped acknowledgements."])
    }

    func testValidClozeOutputPreservesClozeText() throws {
        let section = try makeSection(suffix: "s1-b1")
        var output = AIModelOutput.validFixture(sourceAnchor: "s1-b1")
        output.cards[0].kind = "cloze"
        output.cards[0].clozeText = "A strategic anchor gives {{c1::a decision rule}} for choosing work."

        let result = try AIModelOutputValidator().validate(output, batchSections: [section])

        XCTAssertEqual(result.cards[0].kind, .cloze)
        XCTAssertEqual(result.cards[0].clozeText, "A strategic anchor gives {{c1::a decision rule}} for choosing work.")
    }

    func testRejectsOutOfBatchAnchor() throws {
        let section = try makeSection(suffix: "s1-b1")
        let output = AIModelOutput.validFixture(sourceAnchor: "s1-b2")

        XCTAssertThrowsError(try AIModelOutputValidator().validate(output, batchSections: [section])) { error in
            XCTAssertEqual(error as? AIModelOutputValidationError, .sourceAnchorOutsideBatch("s1-b2"))
        }
    }

    func testRejectsEmptyFrontText() throws {
        let section = try makeSection(suffix: "s1-b1")
        var output = AIModelOutput.validFixture(sourceAnchor: "s1-b1")
        output.cards[0].frontText = "   "

        XCTAssertThrowsError(try AIModelOutputValidator().validate(output, batchSections: [section])) { error in
            XCTAssertEqual(error as? AIModelOutputValidationError, .emptyFrontText("s1-b1"))
        }
    }

    func testRejectsInvalidClozeCardWithoutClozeMarker() throws {
        let section = try makeSection(suffix: "s1-b1")
        var output = AIModelOutput.validFixture(sourceAnchor: "s1-b1")
        output.cards[0].kind = "cloze"
        output.cards[0].clozeText = "Strategy gives a decision rule."

        XCTAssertThrowsError(try AIModelOutputValidator().validate(output, batchSections: [section])) { error in
            XCTAssertEqual(error as? AIModelOutputValidationError, .invalidClozeText("s1-b1"))
        }
    }

    func testRejectsLongSourceQuotation() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let copiedSentence = "Strategic anchors guide choices by naming the tradeoffs teams will accept when pressure makes every option feel urgent"
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Strategy",
            text: "\(copiedSentence). A second sentence gives more context.",
            anchor: anchor
        )
        var output = AIModelOutput.validFixture(sourceAnchor: "s1-b1")
        output.cards[0].backText = copiedSentence

        XCTAssertThrowsError(try AIModelOutputValidator().validate(output, batchSections: [section])) { error in
            XCTAssertEqual(error as? AIModelOutputValidationError, .longSourceQuotation("s1-b1"))
        }
    }

    private func makeSection(suffix: String) throws -> BookSection {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: suffix))
        return BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Strategy",
            text: "Strategic anchors guide choices.",
            anchor: anchor
        )
    }
}

private extension AIModelOutput {
    static func validFixture(sourceAnchor: String) -> AIModelOutput {
        AIModelOutput(
            run: .init(provider: "claude-cli", model: "default", sourceScope: "selected-book", imageMode: "off"),
            bookBrief: .init(
                summary: "Summary",
                themes: ["theme"],
                keyConcepts: ["concept"],
                argumentFlow: ["flow"],
                skipAreas: []
            ),
            cards: [
                .init(
                    sourceAnchor: sourceAnchor,
                    kind: "basic",
                    frontText: "Front",
                    backText: "Back",
                    clozeText: nil,
                    tags: [],
                    importance: 0.7,
                    confidence: 0.8,
                    rationale: "Worth remembering.",
                    visual: nil
                )
            ],
            warnings: []
        )
    }
}
