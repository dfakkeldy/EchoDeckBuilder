import XCTest
@testable import EchoDeckBuilder

final class FoundationModelCardPromptTests: XCTestCase {
    func testPromptIncludesSourceLocationAndTextWithoutInventingAnchors() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s4-b12"))
        let section = BookSection(
            spineIndex: 4,
            blockIndex: 12,
            heading: "Prompt Boundaries",
            text: "Clear instructions keep model output grounded in supplied source text.",
            anchor: anchor
        )

        let prompt = FoundationModelCardPrompt.prompt(for: section, maxCharacters: 500)

        XCTAssertTrue(prompt.contains("Source anchor: s4-b12"))
        XCTAssertTrue(prompt.contains("Heading: Prompt Boundaries"))
        XCTAssertTrue(prompt.contains("Spine index: 4"))
        XCTAssertTrue(prompt.contains("Block index: 12"))
        XCTAssertTrue(prompt.contains(section.text))
        XCTAssertTrue(prompt.contains("Do not create or change source anchors."))
    }

    func testExcerptTrimsWhitespaceAndPrefersSentenceBoundary() {
        let text = " First sentence has useful context. Second sentence is longer than the requested limit. Third sentence. "

        let excerpt = FoundationModelCardPrompt.excerpt(from: text, maxCharacters: 45)

        XCTAssertEqual(excerpt, "First sentence has useful context.")
    }

    func testExcerptFallsBackToCharacterLimitWhenNoSentenceBoundaryExists() {
        let text = "abcdefghijklmnopqrstuvwxyz"

        let excerpt = FoundationModelCardPrompt.excerpt(from: text, maxCharacters: 10)

        XCTAssertEqual(excerpt, "abcdefghij")
    }

    func testInstructionsRequireParaphrasingAndGrounding() {
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Only use the supplied EPUB section"))
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Paraphrase"))
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Do not copy long passages"))
    }
}
