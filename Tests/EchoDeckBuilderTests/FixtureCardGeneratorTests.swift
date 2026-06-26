import XCTest
@testable import EchoDeckBuilder

final class FixtureCardGeneratorTests: XCTestCase {
    func testGeneratorCreatesOneDraftCardPerSectionAndPreservesAnchor() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Prompts",
            text: "Context and constraints guide the model. A second sentence adds detail.",
            anchor: anchor
        )
        let firstSentence = section.text.split(separator: ".").first.map(String.init) ?? section.text

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sectionID, section.id)
        XCTAssertEqual(cards[0].sourceAnchor.suffix, "s2-b3")
        XCTAssertEqual(cards[0].reviewState, .draft)
        XCTAssertTrue(cards[0].backText.contains("context"))
        XCTAssertTrue(cards[0].backText.contains("constraints"))
        XCTAssertNotEqual(cards[0].backText, section.text)
        XCTAssertNotEqual(cards[0].backText, firstSentence)
        XCTAssertFalse(cards[0].frontText.isEmpty)
        XCTAssertFalse(cards[0].backText.isEmpty)
    }

    func testGeneratorUsesExplicitFallbackWhenBodyHasNoExtractableTerms() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s5-b1"))
        let section = BookSection(
            spineIndex: 5,
            blockIndex: 1,
            heading: "Prompts",
            text: " ... ",
            anchor: anchor
        )

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].backText, "This anchored block has no extractable body terms, so review should inspect the source passage.")
        XCTAssertFalse(cards[0].frontText.isEmpty)
    }

    func testGeneratorDoesNotCopyLongHeadingIntoFrontText() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s8-b2"))
        let longHeading = "This heading is intentionally sentence-like and long enough that it should never be copied verbatim into a generated card front"
        let section = BookSection(
            spineIndex: 8,
            blockIndex: 2,
            heading: longHeading,
            text: "Careful summaries should preserve anchors while avoiding copied source headings.",
            anchor: anchor
        )

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards[0].frontText, "What is the key idea in section 8, block 2?")
        XCTAssertFalse(cards[0].frontText.contains(longHeading))
    }
}
