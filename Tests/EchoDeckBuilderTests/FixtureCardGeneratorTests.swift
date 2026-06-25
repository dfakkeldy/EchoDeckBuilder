import XCTest
@testable import EchoDeckBuilder

final class FixtureCardGeneratorTests: XCTestCase {
    func testGeneratorCreatesOneDraftCardPerSectionAndPreservesAnchor() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Prompts",
            text: "Good prompts preserve useful context for the model and make outputs more reliable. This is a second sentence.",
            anchor: anchor
        )
        let firstSentence = section.text.split(separator: ".").first.map(String.init) ?? section.text

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sectionID, section.id)
        XCTAssertEqual(cards[0].sourceAnchor.suffix, "s2-b3")
        XCTAssertEqual(cards[0].reviewState, .draft)
        XCTAssertTrue(cards[0].backText.contains("section 2"))
        XCTAssertTrue(cards[0].backText.contains("block 3"))
        XCTAssertTrue(cards[0].backText.contains("prompts") || cards[0].backText.contains("context"))
        XCTAssertNotEqual(cards[0].backText, section.text)
        XCTAssertNotEqual(cards[0].backText, firstSentence)
        XCTAssertFalse(cards[0].frontText.isEmpty)
        XCTAssertFalse(cards[0].backText.isEmpty)
    }
}
