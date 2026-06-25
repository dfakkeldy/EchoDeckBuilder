import XCTest
@testable import EchoDeckBuilder

final class LibraryStoreTests: XCTestCase {
    func testAcceptingCardChangesReviewState() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "Text",
            anchor: anchor
        )
        let card = DeckCard(
            sectionID: section.id,
            frontText: "Front",
            backText: "Back",
            kind: .basic,
            sourceAnchor: anchor
        )
        let store = LibraryStore(sections: [section], cards: [card])
        store.targetMediaID = "file:///Books/Example"

        store.accept(cardID: card.id)

        XCTAssertEqual(store.cards.first?.reviewState, .accepted)
        XCTAssertTrue(store.canExportEchoDeck)
    }
}
