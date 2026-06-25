import Foundation
import Observation

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

    private let generator: any CardGenerator

    public init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        generator: any CardGenerator = FixtureCardGenerator()
    ) {
        self.sections = sections
        self.cards = cards
        self.selectedSectionID = sections.first?.id
        self.selectedCardID = cards.first?.id
        self.deckName = "Untitled Deck"
        self.targetMediaID = ""
        self.statusMessage = "Ready"
        self.isInspectorPresented = true
        self.generator = generator
    }

    public var selectedSection: BookSection? {
        sections.first { $0.id == selectedSectionID }
    }

    public var selectedCard: DeckCard? {
        cards.first { $0.id == selectedCardID }
    }

    public var canGenerateCards: Bool {
        !sections.isEmpty
    }

    public var canExportEchoDeck: Bool {
        !targetMediaID.isEmpty && cards.contains { $0.reviewState == .accepted }
    }

    public func requestImportPanel() {
        statusMessage = "Use File > Import EPUB... to choose a local EPUB"
    }

    public func requestEchoExportPanel() {
        statusMessage = canExportEchoDeck ? "Echo deck export is ready" : "Accept at least one card and set a target media ID"
    }

    @MainActor
    public func generateCardsForSelectedBook() {
        let generator = self.generator
        let sections = self.sections

        Task { @MainActor in
            do {
                cards = try await generator.generateCards(for: sections)
                selectedCardID = cards.first?.id
                statusMessage = "Generated \(cards.count) draft cards"
            } catch {
                statusMessage = "Card generation failed: \(error.localizedDescription)"
            }
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
}
