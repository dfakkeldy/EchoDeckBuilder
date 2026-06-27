import Foundation
import Observation

@MainActor
@Observable
public final class LibraryStore {
    public var sections: [BookSection]
    public var cards: [DeckCard]
    public var selectedSectionID: BookSection.ID?
    public var selectedCardID: DeckCard.ID?
    public var deckName: String
    public var targetMediaID: String
    public var statusMessage: String
    public var generationSettings: GenerationSettings
    public var isInspectorPresented: Bool
    public var selectedGenerationProvider: CardGenerationProvider
    public private(set) var isGeneratingCards: Bool
    public private(set) var isImportingEPUB: Bool
    public private(set) var latestBookBrief: BookBrief?
    public private(set) var generationWarnings: [GenerationWarning]

    private let generatorResolver: any CardGeneratorResolving
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var generationToken: UUID?
    @ObservationIgnored private var importToken: UUID?

    public convenience init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        generator: any CardGenerator = CompositeCardGenerator()
    ) {
        self.init(
            sections: sections,
            cards: cards,
            selectedGenerationProvider: .fixture,
            generatorResolver: FixedCardGeneratorResolver(
                generator: generator,
                availableProviders: [.fixture, .claudeCLI, .codexCLI]
            )
        )
    }

    public init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        selectedGenerationProvider: CardGenerationProvider = .fixture,
        generatorResolver: any CardGeneratorResolving
    ) {
        self.sections = sections
        self.cards = cards
        self.selectedSectionID = nil
        self.selectedCardID = nil
        self.deckName = "Untitled Deck"
        self.targetMediaID = ""
        self.statusMessage = "Ready"
        self.generationSettings = GenerationSettings()
        self.isInspectorPresented = true
        self.selectedGenerationProvider = selectedGenerationProvider
        self.isGeneratingCards = false
        self.isImportingEPUB = false
        self.latestBookBrief = nil
        self.generationWarnings = []
        self.generatorResolver = generatorResolver

        if let firstCardID = cards.first?.id {
            selectCard(firstCardID)
        } else {
            selectSection(sections.first?.id)
        }
    }

    public var selectedSection: BookSection? {
        sections.first { $0.id == selectedSectionID }
    }

    public var selectedCard: DeckCard? {
        guard let selectedCardID else {
            return nil
        }

        guard let card = cards.first(where: { $0.id == selectedCardID }) else {
            return nil
        }

        guard selectedSectionID == nil || card.sectionID == selectedSectionID else {
            return nil
        }

        return card
    }

    public var generationAvailability: CardGenerationAvailability {
        generatorResolver.availability(for: selectedGenerationProvider)
    }

    public var canGenerateCards: Bool {
        !sections.isEmpty && !isGeneratingCards && !isImportingEPUB && generationAvailability.isAvailable
    }

    public var canExportEchoDeck: Bool {
        !normalizedTargetMediaID.isEmpty && cards.contains { $0.reviewState == .accepted }
    }

    public func selectSection(_ sectionID: BookSection.ID?) {
        guard let sectionID else {
            selectedSectionID = nil
            selectedCardID = nil
            return
        }

        guard sections.contains(where: { $0.id == sectionID }) else {
            return
        }

        selectedSectionID = sectionID
        selectedCardID = cards.first(where: { $0.sectionID == sectionID })?.id
    }

    public func selectCard(_ cardID: DeckCard.ID?) {
        guard let cardID else {
            selectedCardID = nil
            return
        }

        guard let card = cards.first(where: { $0.id == cardID }) else {
            return
        }

        selectedSectionID = card.sectionID
        selectedCardID = card.id
    }

    public func requestImportPanel() {
        statusMessage = "Use File > Import EPUB... to choose a local EPUB"
    }

    public func requestEchoExportPanel() {
        statusMessage = canExportEchoDeck ? "Echo deck export is ready" : "Accept at least one card and set a target media ID"
    }

    public func importEPUB(at epubURL: URL) async {
        guard !isImportingEPUB else {
            statusMessage = "EPUB import is already running"
            return
        }

        let token = UUID()
        importToken = token
        isImportingEPUB = true
        cancelActiveGeneration()
        statusMessage = "Importing EPUB..."

        do {
            let importedBook = try await Self.loadImportedBook(from: epubURL)
            guard importToken == token else {
                return
            }

            sections = importedBook.sections
            cards = []
            latestBookBrief = nil
            generationWarnings = []
            selectSection(sections.first?.id)
            deckName = importedBook.deckName
            statusMessage = "Imported \(sections.count) anchored sections"
        } catch {
            guard importToken == token else {
                return
            }
            statusMessage = "EPUB import failed: \(error.localizedDescription)"
        }

        guard importToken == token else {
            return
        }
        importToken = nil
        isImportingEPUB = false
    }

    public func echoDeckJSONData() throws -> Data {
        try EchoDeckJSONExporter().export(
            deckName: deckName,
            targetMediaID: normalizedTargetMediaID,
            cards: cards
        )
    }

    public func ankiTSV() -> String {
        AnkiTSVExporter().export(cards: cards)
    }

    public func generateCardsForSelectedBook() {
        guard generationTask == nil else {
            statusMessage = "Card generation is already running"
            return
        }

        guard !isImportingEPUB else {
            statusMessage = "Wait for EPUB import to finish before generating cards"
            return
        }

        let availability = generationAvailability
        guard availability.isAvailable else {
            statusMessage = availability.message
            return
        }

        let generator = generatorResolver.generator(for: selectedGenerationProvider)
        let sections = self.sections
        let acceptedCards = self.cards.filter { $0.reviewState == .accepted }
        var settings = self.generationSettings
        settings.provider = selectedGenerationProvider
        let targetMediaID = normalizedTargetMediaID.nilIfEmpty
        let preferredSectionID = selectedSectionID ?? sections.first?.id
        let token = UUID()

        generationToken = token
        isGeneratingCards = true
        statusMessage = "Generating draft cards..."

        generationTask = Task { [weak self, generator, sections, acceptedCards, settings, targetMediaID, preferredSectionID, token] in
            await self?.runGeneration(
                using: generator,
                request: CardGenerationRequest(
                    sections: sections,
                    acceptedCards: acceptedCards,
                    settings: settings,
                    sourceScope: .selectedBook,
                    targetMediaID: targetMediaID
                ),
                preferredSectionID: preferredSectionID,
                token: token
            )
        }
    }

    public func accept(cardID: DeckCard.ID) {
        update(cardID: cardID) { $0.reviewState = .accepted }
    }

    public func reject(cardID: DeckCard.ID) {
        update(cardID: cardID) { $0.reviewState = .rejected }
    }

    public func update(cardID: DeckCard.ID, mutate: (inout DeckCard) -> Void) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        mutate(&cards[index])
    }

    public func card(id cardID: DeckCard.ID) -> DeckCard? {
        cards.first { $0.id == cardID }
    }

    private func runGeneration(
        using generator: any CardGenerator,
        request: CardGenerationRequest,
        preferredSectionID: BookSection.ID?,
        token: UUID
    ) async {
        do {
            let result = try await generator.generateCards(for: request)
            finishGeneration(with: result, preferredSectionID: preferredSectionID, token: token)
        } catch {
            guard !Task.isCancelled else {
                cancelGeneration(token: token)
                return
            }

            failGeneration(error, token: token)
        }
    }

    private func finishGeneration(
        with result: CardGenerationResult,
        preferredSectionID: BookSection.ID?,
        token: UUID
    ) {
        guard generationToken == token else {
            return
        }

        let acceptedCards = cards.filter { $0.reviewState == .accepted }
        let draftCards = result.cards.map { card -> DeckCard in
            var draft = card
            draft.reviewState = .draft
            return draft
        }

        cards = acceptedCards + draftCards
        latestBookBrief = result.bookBrief
        generationWarnings = result.warnings
        generationTask = nil
        generationToken = nil
        isGeneratingCards = false
        statusMessage = "Generated \(draftCards.count) draft cards"

        if let selectedCardID = preferredDraftSelection(
            preferredSectionID: preferredSectionID,
            draftCards: draftCards
        ) {
            selectCard(selectedCardID)
        } else if let preferredSectionID {
            selectSection(preferredSectionID)
        } else if let firstCardID = draftCards.first?.id ?? acceptedCards.first?.id {
            selectCard(firstCardID)
        } else {
            selectSection(sections.first?.id)
        }
    }

    private func preferredDraftSelection(
        preferredSectionID: BookSection.ID?,
        draftCards: [DeckCard]
    ) -> DeckCard.ID? {
        if let preferredSectionID,
           let firstDraftInPreferredSection = draftCards.first(where: { $0.sectionID == preferredSectionID }) {
            return firstDraftInPreferredSection.id
        }

        return preferredSectionID == nil ? draftCards.first?.id : nil
    }

    private func failGeneration(_ error: any Error, token: UUID) {
        guard generationToken == token else {
            return
        }

        generationTask = nil
        generationToken = nil
        isGeneratingCards = false
        statusMessage = "Card generation failed: \(error.localizedDescription)"
    }

    private func cancelGeneration(token: UUID) {
        guard generationToken == token else {
            return
        }

        generationTask = nil
        generationToken = nil
        isGeneratingCards = false
    }

    private func cancelActiveGeneration() {
        generationTask?.cancel()
        generationTask = nil
        generationToken = nil
        isGeneratingCards = false
    }

    nonisolated private static func loadImportedBook(from epubURL: URL) async throws -> ImportedBook {
        try await Task.detached(priority: .userInitiated) {
            let extractedURL = try await EPUBArchiveExtractor().extract(epubURL: epubURL)
            defer { try? FileManager.default.removeItem(at: extractedURL) }

            let sections = try EchoCompatibleEPUBParser()
                .sections(fromExtractedEPUBRoot: extractedURL)

            return ImportedBook(
                deckName: epubURL.deletingPathExtension().lastPathComponent,
                sections: sections
            )
        }.value
    }

    private var normalizedTargetMediaID: String {
        targetMediaID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct ImportedBook: Sendable {
    let deckName: String
    let sections: [BookSection]
}
