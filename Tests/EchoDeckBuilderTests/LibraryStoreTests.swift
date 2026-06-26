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
        let newDraft = DeckCard(
            sectionID: fixture.section.id,
            frontText: "New draft",
            backText: "New draft back",
            kind: .basic,
            sourceAnchor: fixture.section.anchor
        )
        let generator = ResultCardGenerator(result: CardGenerationResult(bookBrief: .fixture, cards: [newDraft]))
        let store = LibraryStore(sections: [fixture.section], cards: [accepted, oldDraft], generator: generator)

        store.generateCardsForSelectedBook()
        try await Task.sleep(nanoseconds: 25_000_000)

        XCTAssertTrue(store.cards.contains { $0.id == accepted.id && $0.reviewState == .accepted })
        XCTAssertFalse(store.cards.contains { $0.id == oldDraft.id })
        XCTAssertTrue(store.cards.contains { $0.frontText == "New draft" && $0.reviewState == .draft })
    }

    func testGenerationRequestIncludesAcceptedCardsAndSettings() async throws {
        let fixture = try makeFixture()
        var accepted = fixture.card
        accepted.reviewState = .accepted
        let generator = RecordingRequestGenerator(result: CardGenerationResult(bookBrief: .fixture, cards: []))
        let store = LibraryStore(sections: [fixture.section], cards: [accepted], generator: generator)
        store.generationSettings.provider = .claudeCLI
        store.generationSettings.imageMode = .prompts

        store.generateCardsForSelectedBook()
        try await Task.sleep(nanoseconds: 25_000_000)
        let recordedRequest = await generator.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)

        XCTAssertEqual(request.acceptedCards.map(\.id), [accepted.id])
        XCTAssertEqual(request.settings.provider, .claudeCLI)
        XCTAssertEqual(request.settings.imageMode, .prompts)
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
        try await Task.sleep(nanoseconds: 25_000_000)

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
        try await Task.sleep(nanoseconds: 25_000_000)

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
        try await Task.sleep(nanoseconds: 25_000_000)

        XCTAssertEqual(store.sections.count, 1)
        XCTAssertEqual(store.sections.first?.heading, "Fixture Chapter")
        XCTAssertEqual(store.cards, [])
        XCTAssertFalse(store.isGeneratingCards)
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

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        callCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return CardGenerationResult(bookBrief: .fixture, cards: cards)
    }

    func recordedCallCount() -> Int {
        callCount
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
