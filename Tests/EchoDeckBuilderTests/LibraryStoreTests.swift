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

    func testExportTrimsTargetMediaIDAndRejectsWhitespaceOnlyValue() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(sections: [fixture.section], cards: [fixture.card])

        store.accept(cardID: fixture.card.id)
        store.targetMediaID = " \n\t "

        XCTAssertFalse(store.canExportEchoDeck)

        store.targetMediaID = "  file:///Books/Example  \n"
        let data = try store.echoDeckJSONData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(store.canExportEchoDeck)
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

    func testImportInvalidatesStaleGenerationCompletion() async throws {
        let fixture = try makeFixture()
        let staleCard = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Stale front",
            backText: "Stale back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        let generator = ManuallyCompletingCardGenerator(cards: [staleCard])
        let store = LibraryStore(sections: [fixture.section], generator: generator)
        let epubFixture = try TestEPUBFixture.make()
        defer { epubFixture.cleanup() }

        store.generateCardsForSelectedBook()
        await generator.waitForGenerationToStart()

        await store.importEPUB(at: epubFixture.epubURL)
        await generator.finish()
        try await Task.sleep(nanoseconds: 25_000_000)

        XCTAssertEqual(store.sections.count, 1)
        XCTAssertEqual(store.sections.first?.heading, "Fixture Chapter")
        XCTAssertEqual(store.cards, [])
        XCTAssertFalse(store.isGeneratingCards)
    }

    func testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .foundationModels,
            generatorResolver: UnavailableFoundationModelResolver()
        )

        XCTAssertFalse(store.canGenerateCards)
        XCTAssertEqual(store.generationAvailability.message, "Foundation Models requires macOS 26+")

        store.generateCardsForSelectedBook()

        XCTAssertEqual(store.statusMessage, "Foundation Models requires macOS 26+")
        XCTAssertFalse(store.isGeneratingCards)
        XCTAssertEqual(store.cards, [])
    }

    func testSelectedProviderUsesResolverGenerator() async throws {
        let fixture = try makeFixture()
        let generatedCard = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Foundation front",
            backText: "Foundation back",
            kind: .basic,
            tags: ["generated", "foundation-models"],
            sourceAnchor: fixture.section.anchor
        )
        let resolver = ProviderRecordingResolver(cards: [generatedCard])
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .foundationModels,
            generatorResolver: resolver
        )

        store.generateCardsForSelectedBook()

        try await Task.sleep(for: .milliseconds(25))
        let requestedProviders = await resolver.requestedProviders()

        XCTAssertEqual(requestedProviders, [.foundationModels])
        XCTAssertEqual(store.cards, [generatedCard])
        XCTAssertEqual(store.statusMessage, "Generated 1 draft cards")
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

private struct UnavailableFoundationModelResolver: CardGeneratorResolving {
    func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return .unavailable("Foundation Models requires macOS 26+")
        }
    }

    func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        FixtureCardGenerator()
    }
}

private actor ProviderRecordingResolver: CardGeneratorResolving {
    private let cards: [DeckCard]
    private var providers: [CardGenerationProvider] = []

    init(cards: [DeckCard]) {
        self.cards = cards
    }

    nonisolated func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        .available("\(provider.displayName) ready")
    }

    nonisolated func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        RecordingGenerator(owner: self, provider: provider, cards: cards)
    }

    func record(_ provider: CardGenerationProvider) {
        providers.append(provider)
    }

    func requestedProviders() -> [CardGenerationProvider] {
        providers
    }
}

private struct RecordingGenerator: CardGenerator {
    let owner: ProviderRecordingResolver
    let provider: CardGenerationProvider
    let cards: [DeckCard]

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        await owner.record(provider)
        return cards
    }
}

private actor ManuallyCompletingCardGenerator: CardGenerator {
    private let cards: [DeckCard]
    private var generationContinuation: CheckedContinuation<[DeckCard], Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    init(cards: [DeckCard]) {
        self.cards = cards
    }

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        startContinuations.forEach { $0.resume() }
        startContinuations = []

        return await withCheckedContinuation { continuation in
            generationContinuation = continuation
        }
    }

    func waitForGenerationToStart() async {
        if generationContinuation != nil {
            return
        }

        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func finish() {
        generationContinuation?.resume(returning: cards)
        generationContinuation = nil
    }
}
