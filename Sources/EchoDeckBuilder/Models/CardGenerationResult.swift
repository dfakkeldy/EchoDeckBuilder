import Foundation

public struct GenerationWarning: Codable, Hashable, Sendable {
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

public struct CardGenerationResult: Sendable {
    public var bookBrief: BookBrief
    public var cards: [DeckCard]
    public var warnings: [GenerationWarning]

    public init(
        bookBrief: BookBrief,
        cards: [DeckCard],
        warnings: [GenerationWarning] = []
    ) {
        self.bookBrief = bookBrief
        self.cards = cards
        self.warnings = warnings
    }
}
