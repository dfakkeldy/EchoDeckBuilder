import XCTest
@testable import EchoDeckBuilder

final class FixtureCardGeneratorTests: XCTestCase {
    func testGeneratorCreatesOneDraftCardPerSectionAndPreservesAnchor() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Prompts",
            text: "Good prompts preserve useful context for the model.",
            anchor: anchor
        )

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sectionID, section.id)
        XCTAssertEqual(cards[0].sourceAnchor.suffix, "s2-b3")
        XCTAssertEqual(cards[0].reviewState, .draft)
        XCTAssertFalse(cards[0].frontText.isEmpty)
        XCTAssertFalse(cards[0].backText.isEmpty)
    }
}
