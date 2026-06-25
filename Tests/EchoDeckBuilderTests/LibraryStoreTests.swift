import XCTest
@testable import EchoDeckBuilder

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testAcceptingCardChangesReviewState() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(sections: [fixture.section], cards: [fixture.card])
        store.targetMediaID = "file:///Books/Example"

        store.accept(cardID: fixture.card.id)

        XCTAssertEqual(store.cards.first?.reviewState, .accepted)
        XCTAssertTrue(store.canExportEchoDeck)
    }

    func testSelectingSectionResetsSelectedCardToSectionCard() throws {
        let intro = try makeFixture(heading: "Intro", suffix: "s1-b1", text: "First")
        let advanced = try makeFixture(heading: "Advanced", suffix: "s1-b2", text: "Second")
        let store = LibraryStore(
            sections: [intro.section, advanced.section],
            cards: [intro.card, advanced.card]
        )

        store.selectCard(advanced.card.id)
        store.selectSection(intro.section.id)

        XCTAssertEqual(store.selectedSectionID, intro.section.id)
        XCTAssertEqual(store.selectedCardID, intro.card.id)
        XCTAssertEqual(store.selectedCard?.sectionID, intro.section.id)
    }

    func testSelectingCardUpdatesSectionSelection() throws {
        let intro = try makeFixture(heading: "Intro", suffix: "s1-b1", text: "First")
        let advanced = try makeFixture(heading: "Advanced", suffix: "s1-b2", text: "Second")
        let store = LibraryStore(
            sections: [intro.section, advanced.section],
            cards: [intro.card, advanced.card]
        )

        store.selectCard(advanced.card.id)

        XCTAssertEqual(store.selectedSectionID, advanced.section.id)
        XCTAssertEqual(store.selectedCardID, advanced.card.id)
    }

    func testExportRequiresAcceptedCards() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(sections: [fixture.section], cards: [fixture.card])
        store.targetMediaID = "file:///Books/Example"

        XCTAssertFalse(store.canExportEchoDeck)
    }

    func testExportRequiresTargetMediaID() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(sections: [fixture.section], cards: [fixture.card])

        store.accept(cardID: fixture.card.id)

        XCTAssertFalse(store.canExportEchoDeck)
    }

    func testEchoDeckJSONDataUsesAcceptedCardsAndTargetMediaID() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "Text",
            anchor: anchor
        )
        var card = DeckCard(
            sectionID: section.id,
            frontText: "Front",
            backText: "Back",
            kind: .basic,
            sourceAnchor: anchor
        )
        card.reviewState = .accepted
        let store = LibraryStore(sections: [section], cards: [card])
        store.deckName = "Intro Deck"
        store.targetMediaID = "file:///Books/Example"

        let data = try store.echoDeckJSONData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["deckName"] as? String, "Intro Deck")
        XCTAssertEqual(object["targetMediaID"] as? String, "file:///Books/Example")
    }

    func testGenerateCardsPreventsOverlappingRequests() async throws {
        let fixture = try makeFixture()
        let generatedCard = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Generated front",
            backText: "Generated back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        let generator = CountingCardGenerator(cards: [generatedCard], delayNanoseconds: 50_000_000)
        let store = LibraryStore(sections: [fixture.section], generator: generator)

        store.generateCardsForSelectedBook()
        store.generateCardsForSelectedBook()

        XCTAssertTrue(store.isGeneratingCards)
        XCTAssertEqual(store.statusMessage, "Card generation is already running")

        try await Task.sleep(nanoseconds: 100_000_000)
        let callCount = await generator.recordedCallCount()

        XCTAssertFalse(store.isGeneratingCards)
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.cards, [generatedCard])
        XCTAssertEqual(store.selectedSectionID, fixture.section.id)
        XCTAssertEqual(store.selectedCardID, generatedCard.id)
    }

    private func makeFixture(
        heading: String = "Intro",
        suffix: String = "s1-b1",
        text: String = "Text"
    ) throws -> (section: BookSection, card: DeckCard) {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: suffix))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: heading,
            text: text,
            anchor: anchor
        )
        let card = DeckCard(
            sectionID: section.id,
            frontText: "Front",
            backText: "Back",
            kind: .basic,
            sourceAnchor: anchor
        )
        return (section, card)
    }
}

private actor CountingCardGenerator: CardGenerator {
    private let cards: [DeckCard]
    private let delayNanoseconds: UInt64
    private var callCount = 0

    init(cards: [DeckCard], delayNanoseconds: UInt64) {
        self.cards = cards
        self.delayNanoseconds = delayNanoseconds
    }

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        callCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return cards
    }

    func recordedCallCount() -> Int {
        callCount
    }
}
