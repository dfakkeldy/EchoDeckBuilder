import XCTest
@testable import EchoDeckBuilder

final class AIPromptPackageBuilderTests: XCTestCase {
    func testBookBriefPromptIncludesHeadingsSettingsAndAcceptedCards() throws {
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
        XCTAssertTrue(prompt.contains("<source-outline>"))
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
