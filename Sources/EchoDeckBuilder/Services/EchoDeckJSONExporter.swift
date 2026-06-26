import Foundation

public struct EchoDeckJSONExporter: Sendable {
    public init() {}

    public func summary(for cards: [DeckCard]) -> EchoDeckExportSummary {
        let acceptedCards = cards.filter { $0.reviewState == .accepted }
        let sourceAnchoredCards = acceptedCards.filter { $0.sourceAnchor != nil }
        return EchoDeckExportSummary(
            totalCards: cards.count,
            acceptedCount: acceptedCards.count,
            draftCount: cards.filter { $0.reviewState == .draft }.count,
            rejectedCount: cards.filter { $0.reviewState == .rejected }.count,
            exportedCount: acceptedCards.count,
            sourceAnchoredCount: sourceAnchoredCards.count
        )
    }

    public func export(deckName: String, targetMediaID: String, cards: [DeckCard]) throws -> Data {
        let exportCards = cards
            .filter { $0.reviewState == .accepted }
            .map { card in
                EchoDeckCardDocument(
                    frontText: card.frontText,
                    backText: card.backText,
                    triggerTiming: "manualOnly",
                    sourceAnchor: card.sourceAnchor?.suffix ?? ""
                )
            }

        let document = EchoDeckDocument(deckName: deckName, targetMediaID: targetMediaID, cards: exportCards)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }
}
