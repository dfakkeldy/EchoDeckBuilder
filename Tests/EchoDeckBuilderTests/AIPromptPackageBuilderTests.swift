import XCTest
@testable import EchoDeckBuilder

final class AIPromptPackageBuilderTests: XCTestCase {
    func testBookBriefPromptIncludesHeadingsSettingsAcceptedCardsAndRepresentativeSourceText() throws {
        let section = try makeSection(suffix: "s1-b1", heading: "Anchors", text: "Anchors connect memory to source.")
        let accepted = DeckCard(
            sectionID: section.id,
            frontText: "Accepted front",
            backText: "Accepted back",
            kind: .basic,
            sourceAnchor: section.anchor,
            reviewState: .accepted
        )
        let request = CardGenerationRequest(
            sections: [section],
            acceptedCards: [accepted],
            settings: GenerationSettings(provider: .claudeCLI, imageMode: .prompts)
        )

        let prompt = AIPromptPackageBuilder().bookBriefPrompt(for: request)

        XCTAssertTrue(prompt.contains("Provider: claudeCLI"))
        XCTAssertTrue(prompt.contains("Image mode: prompts"))
        XCTAssertTrue(prompt.contains("s1-b1 Anchors"))
        XCTAssertTrue(prompt.contains("Accepted front"))
        XCTAssertTrue(prompt.contains("<representative-source-text>"))
        XCTAssertTrue(prompt.contains("Anchors connect memory to source."))
        XCTAssertTrue(prompt.contains("<source-outline>"))
        XCTAssertTrue(prompt.contains("<source-sample anchor=\"s1-b1\">"))
        XCTAssertTrue(prompt.contains("Heading: Anchors"))
    }

    func testBookBriefPromptFiltersAcceptedCardsInSummary() throws {
        let section = try makeSection(suffix: "s1-b1", heading: "Anchors", text: "Anchors connect memory to source.")
        let accepted = DeckCard(
            sectionID: section.id,
            frontText: "Accepted front",
            backText: "Accepted back",
            kind: .basic,
            sourceAnchor: section.anchor,
            reviewState: .accepted
        )
        let rejected = DeckCard(
            sectionID: section.id,
            frontText: "Rejected front",
            backText: "Rejected back",
            kind: .basic,
            sourceAnchor: section.anchor,
            reviewState: .rejected
        )
        let request = CardGenerationRequest(
            sections: [section],
            acceptedCards: [accepted, rejected],
            settings: GenerationSettings(provider: .claudeCLI, imageMode: .prompts)
        )

        let prompt = AIPromptPackageBuilder().bookBriefPrompt(for: request)

        XCTAssertTrue(prompt.contains("Accepted front"))
        XCTAssertFalse(prompt.contains("Rejected front"))
    }

    func testBookBriefPromptUsesBoundedRepresentativeSourceSamples() throws {
        let longText = String(repeating: "important context ", count: 70) + "TAIL_SHOULD_NOT_APPEAR"
        let sections = try (1...30).map { index in
            try makeSection(
                suffix: "s1-b\(index)",
                heading: "Heading \(index)",
                text: index == 1 ? longText : "Representative text \(index)"
            )
        }
        let request = CardGenerationRequest(sections: sections, settings: GenerationSettings(provider: .claudeCLI))

        let prompt = AIPromptPackageBuilder().bookBriefPrompt(for: request)

        XCTAssertTrue(prompt.contains("Showing 24 representative source samples from 30 sections."))
        XCTAssertTrue(prompt.contains("<source-sample anchor=\"s1-b1\">"))
        XCTAssertTrue(prompt.contains("<source-sample anchor=\"s1-b30\">"))
        XCTAssertFalse(prompt.contains("<source-sample anchor=\"s1-b10\">"))
        XCTAssertFalse(prompt.contains("TAIL_SHOULD_NOT_APPEAR"))
    }

    func testBatchPromptIncludesVisualInstructionsForPromptMode() throws {
        let section = try makeSection(suffix: "s2-b4", heading: "Context", text: "Context prevents shallow cards.")
        let request = CardGenerationRequest(
            sections: [section],
            settings: GenerationSettings(provider: .claudeCLI, imageMode: .prompts)
        )
        let brief = BookBrief(summary: "Big picture", themes: ["context"], keyConcepts: ["batching"], argumentFlow: [], skipAreas: [])

        let prompt = AIPromptPackageBuilder().batchPrompt(for: request, bookBrief: brief, batch: [section])

        XCTAssertTrue(prompt.contains("<visual-instructions>"))
        XCTAssertTrue(prompt.contains("When imageMode is prompts, include `visual` metadata only for high-value cards where a strong image prompt would help memorability."))
        XCTAssertFalse(prompt.contains("When imageMode is off"))
    }

    func testBatchPromptSetsVisualToNullOrOmitsWhenImageModeOff() throws {
        let section = try makeSection(suffix: "s2-b4", heading: "Context", text: "Context prevents shallow cards.")
        let request = CardGenerationRequest(
            sections: [section],
            settings: GenerationSettings(provider: .claudeCLI, imageMode: .off)
        )
        let brief = BookBrief(summary: "Big picture", themes: ["context"], keyConcepts: ["batching"], argumentFlow: [], skipAreas: [])

        let prompt = AIPromptPackageBuilder().batchPrompt(for: request, bookBrief: brief, batch: [section])

        XCTAssertTrue(prompt.contains("<visual-instructions>"))
        XCTAssertTrue(prompt.contains("When imageMode is off, do not provide image prompts. Set `visual` to null or omit it."))
        XCTAssertFalse(prompt.contains("only for high-value cards"))
    }

    func testBatchPromptDelimitsSourceBlocksAndRequiresInBatchAnchors() throws {
        let section = try makeSection(suffix: "s2-b4", heading: "Context", text: "Context prevents shallow cards.")
        let request = CardGenerationRequest(sections: [section], settings: GenerationSettings(provider: .claudeCLI))
        let brief = BookBrief(summary: "Big picture", themes: ["context"], keyConcepts: ["batching"], argumentFlow: [], skipAreas: [])

        let prompt = AIPromptPackageBuilder().batchPrompt(for: request, bookBrief: brief, batch: [section])

        XCTAssertTrue(prompt.contains("<book-brief>"))
        XCTAssertTrue(prompt.contains("Big picture"))
        XCTAssertTrue(prompt.contains("<source-block anchor=\"s2-b4\">"))
        XCTAssertTrue(prompt.contains("Use only source anchors from this batch."))
    }

    func testOutputSchemaDataContainsRequiredTopLevelKeys() throws {
        let data = try AIPromptPackageBuilder().outputSchemaData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let required = try XCTUnwrap(object["required"] as? [String])

        XCTAssertTrue(required.contains("run"))
        XCTAssertTrue(required.contains("bookBrief"))
        XCTAssertTrue(required.contains("cards"))
        XCTAssertTrue(required.contains("warnings"))
    }

    private func makeSection(suffix: String, heading: String, text: String) throws -> BookSection {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: suffix))
        return BookSection(spineIndex: 1, blockIndex: 1, heading: heading, text: text, anchor: anchor)
    }
}
