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
    public var isInspectorPresented: Bool
    public private(set) var isGeneratingCards: Bool

    private let generator: any CardGenerator
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    public init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        generator: any CardGenerator = FixtureCardGenerator()
    ) {
        self.sections = sections
        self.cards = cards
        self.selectedSectionID = nil
        self.selectedCardID = nil
        self.deckName = "Untitled Deck"
        self.targetMediaID = ""
        self.statusMessage = "Ready"
        self.isInspectorPresented = true
        self.isGeneratingCards = false
        self.generator = generator

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

    public var canGenerateCards: Bool {
        !sections.isEmpty && !isGeneratingCards
    }

    public var canExportEchoDeck: Bool {
        !targetMediaID.isEmpty && cards.contains { $0.reviewState == .accepted }
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

    public func generateCardsForSelectedBook() {
        guard generationTask == nil else {
            statusMessage = "Card generation is already running"
            return
        }

        let generator = self.generator
        let sections = self.sections
        let preferredSectionID = selectedSectionID ?? sections.first?.id

        isGeneratingCards = true
        statusMessage = "Generating draft cards..."

        generationTask = Task { [weak self, generator, sections, preferredSectionID] in
            await self?.runGeneration(
                using: generator,
                sections: sections,
                preferredSectionID: preferredSectionID
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

    private func runGeneration(
        using generator: any CardGenerator,
        sections: [BookSection],
        preferredSectionID: BookSection.ID?
    ) async {
        do {
            let generatedCards = try await generator.generateCards(for: sections)
            finishGeneration(with: generatedCards, preferredSectionID: preferredSectionID)
        } catch {
            guard !Task.isCancelled else {
                cancelGeneration()
                return
            }

            failGeneration(error)
        }
    }

    private func finishGeneration(
        with generatedCards: [DeckCard],
        preferredSectionID: BookSection.ID?
    ) {
        cards = generatedCards
        generationTask = nil
        isGeneratingCards = false
        statusMessage = "Generated \(generatedCards.count) draft cards"

        if let preferredSectionID {
            selectSection(preferredSectionID)
        } else if let firstCardID = generatedCards.first?.id {
            selectCard(firstCardID)
        } else {
            selectSection(sections.first?.id)
        }
    }

    private func failGeneration(_ error: any Error) {
        generationTask = nil
        isGeneratingCards = false
        statusMessage = "Card generation failed: \(error.localizedDescription)"
    }

    private func cancelGeneration() {
        generationTask = nil
        isGeneratingCards = false
    }
}
