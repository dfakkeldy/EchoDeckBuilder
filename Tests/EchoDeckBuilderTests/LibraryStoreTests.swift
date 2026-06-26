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

        try await waitForGenerationToFinish(store)
        let callCount = await generator.recordedCallCount()

        XCTAssertFalse(store.isGeneratingCards)
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.cards, [generatedCard])
        XCTAssertEqual(store.selectedSectionID, fixture.section.id)
        XCTAssertEqual(store.selectedCardID, generatedCard.id)
    }

    func testRegenerationPreservesAcceptedCardsAndReplacesDrafts() async throws {
        let fixture = try makeFixture()
        var accepted = fixture.card
        accepted.reviewState = .accepted
        let oldDraft = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Old draft",
            backText: "Old draft back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        var oldRejected = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Old rejected",
            backText: "Old rejected back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        oldRejected.reviewState = .rejected
        let newDraft = DeckCard(
            sectionID: fixture.section.id,
            frontText: "New draft",
            backText: "New draft back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        let generator = ResultCardGenerator(result: CardGenerationResult(bookBrief: .fixture, cards: [newDraft]))
        let store = LibraryStore(sections: [fixture.section], cards: [accepted, oldDraft, oldRejected], generator: generator)

        store.generateCardsForSelectedBook()
        try await waitForGenerationToFinish(store)

        XCTAssertTrue(store.cards.contains { $0.id == accepted.id && $0.reviewState == .accepted })
        XCTAssertFalse(store.cards.contains { $0.id == oldDraft.id })
        XCTAssertFalse(store.cards.contains { $0.id == oldRejected.id })
        XCTAssertTrue(store.cards.contains { $0.frontText == "New draft" && $0.reviewState == .draft })
        XCTAssertEqual(store.selectedCardID, newDraft.id)
    }

    func testRegenerationStaysOnPreferredSectionWhenNoFreshDraftExistsThere() async throws {
        let preferred = try makeFixture(heading: "Preferred", suffix: "s1-b1", text: "Preferred text")
        let other = try makeFixture(heading: "Other", suffix: "s1-b2", text: "Other text")
        var accepted = preferred.card
        accepted.reviewState = .accepted
        let otherDraft = DeckCard(
            sectionID: other.section.id,
            frontText: "Other draft",
            backText: "Other draft back",
            kind: .basic,
            sourceAnchor: other.section.anchor
        )
        let generator = ResultCardGenerator(result: CardGenerationResult(bookBrief: .fixture, cards: [otherDraft]))
        let store = LibraryStore(
            sections: [preferred.section, other.section],
            cards: [accepted],
            generator: generator
        )
        store.selectSection(preferred.section.id)

        store.generateCardsForSelectedBook()
        try await waitForGenerationToFinish(store)

        XCTAssertEqual(store.selectedSectionID, preferred.section.id)
        XCTAssertEqual(store.selectedCardID, accepted.id)
    }

    func testGenerationRequestIncludesAcceptedCardsAndSettings() async throws {
        let fixture = try makeFixture()
        var accepted = fixture.card
        accepted.reviewState = .accepted
        let generator = RecordingRequestGenerator(result: CardGenerationResult(bookBrief: .fixture, cards: []))
        let store = LibraryStore(sections: [fixture.section], cards: [accepted], generator: generator)
        store.selectedGenerationProvider = .claudeCLI
        store.generationSettings.imageMode = .prompts
        store.targetMediaID = "  media-123  "

        store.generateCardsForSelectedBook()
        try await waitForGenerationToFinish(store)
        let recordedRequest = await generator.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)

        XCTAssertEqual(request.acceptedCards.map(\.id), [accepted.id])
        XCTAssertEqual(request.settings.provider, .claudeCLI)
        XCTAssertEqual(request.settings.imageMode, .prompts)
        XCTAssertEqual(request.sourceScope, .selectedBook)
        XCTAssertEqual(request.targetMediaID, "media-123")
    }

    func testGenerationStoresLatestBriefAndWarnings() async throws {
        let fixture = try makeFixture()
        let result = CardGenerationResult(
            bookBrief: BookBrief(summary: "Fresh brief", themes: ["theme"]),
            cards: [],
            warnings: [GenerationWarning(message: "Batch warning")]
        )
        let store = LibraryStore(sections: [fixture.section], generator: ResultCardGenerator(result: result))

        store.generateCardsForSelectedBook()
        try await waitForGenerationToFinish(store)

        XCTAssertEqual(store.latestBookBrief?.summary, "Fresh brief")
        XCTAssertEqual(store.generationWarnings.map(\.message), ["Batch warning"])
    }

    func testImportClearsLatestBriefAndWarnings() async throws {
        let fixture = try makeFixture()
        let result = CardGenerationResult(
            bookBrief: BookBrief(summary: "Fresh brief", themes: ["theme"]),
            cards: [],
            warnings: [GenerationWarning(message: "Batch warning")]
        )
        let store = LibraryStore(sections: [fixture.section], generator: ResultCardGenerator(result: result))
        let epubFixture = try TestEPUBFixture.make()
        defer { epubFixture.cleanup() }

        store.generateCardsForSelectedBook()
        try await waitForGenerationToFinish(store)

        XCTAssertNotNil(store.latestBookBrief)
        XCTAssertFalse(store.generationWarnings.isEmpty)

        await store.importEPUB(at: epubFixture.epubURL)

        XCTAssertNil(store.latestBookBrief)
        XCTAssertEqual(store.generationWarnings, [])
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
        await yieldForMainActorWork()

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

    func testLegacyGeneratorInitializerKeepsFoundationModelsUnavailable() async throws {
        let fixture = try makeFixture()
        let generator = CountingCardGenerator(cards: [fixture.card], delayNanoseconds: 0)
        let store = LibraryStore(sections: [fixture.section], generator: generator)

        store.selectedGenerationProvider = .foundationModels

        XCTAssertFalse(store.generationAvailability.isAvailable)
        XCTAssertEqual(
            store.generationAvailability.message,
            "Foundation Models generator is not connected yet"
        )
        XCTAssertFalse(store.canGenerateCards)

        store.generateCardsForSelectedBook()

        let callCount = await generator.recordedCallCount()

        XCTAssertEqual(store.statusMessage, "Foundation Models generator is not connected yet")
        XCTAssertFalse(store.isGeneratingCards)
        XCTAssertEqual(store.cards, [])
        XCTAssertEqual(callCount, 0)
    }

    func testChangingSelectedGenerationProviderUpdatesAvailability() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .fixture,
            generatorResolver: UnavailableFoundationModelResolver()
        )

        XCTAssertEqual(store.generationAvailability.message, "Fixture generator ready")
        XCTAssertTrue(store.canGenerateCards)

        store.selectedGenerationProvider = .foundationModels

        XCTAssertEqual(store.generationAvailability.message, "Foundation Models requires macOS 26+")
        XCTAssertFalse(store.canGenerateCards)
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

    private func waitForGenerationToFinish(
        _ store: LibraryStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<100 {
            if store.isGeneratingCards == false {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for card generation to finish.", file: file, line: line)
    }

    private func yieldForMainActorWork() async {
        for _ in 0..<5 {
            await Task.yield()
        }
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

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        callCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return CardGenerationResult(bookBrief: .fixture, cards: cards)
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
        case .claudeCLI:
            return .available("Claude CLI ready")
        case .codexCLI:
            return .available("Codex CLI ready")
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

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        await owner.record(provider)
        return CardGenerationResult(bookBrief: .fixture, cards: cards)
    }
}

private actor ManuallyCompletingCardGenerator: CardGenerator {
    private let cards: [DeckCard]
    private var generationContinuation: CheckedContinuation<[DeckCard], Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    init(cards: [DeckCard]) {
        self.cards = cards
    }

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        startContinuations.forEach { $0.resume() }
        startContinuations = []

        let generatedCards = await withCheckedContinuation { continuation in
            generationContinuation = continuation
        }

        return CardGenerationResult(bookBrief: .fixture, cards: generatedCards)
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

private actor ResultCardGenerator: CardGenerator {
    private let result: CardGenerationResult

    init(result: CardGenerationResult) {
        self.result = result
    }

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        result
    }
}

private actor RecordingRequestGenerator: CardGenerator {
    private let result: CardGenerationResult
    private var request: CardGenerationRequest?

    init(result: CardGenerationResult) {
        self.result = result
    }

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        self.request = request
        return result
    }

    func recordedRequest() -> CardGenerationRequest? {
        request
    }
}
