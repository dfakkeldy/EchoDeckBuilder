import Foundation

public struct GenerationWarning: Codable, Hashable, Sendable {
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

public struct GenerationRunMetadata: Codable, Hashable, Sendable {
    public var provider: String
    public var model: String
    public var sourceScope: String
    public var imageMode: String

    public init(provider: String, model: String, sourceScope: String, imageMode: String) {
        self.provider = provider
        self.model = model
        self.sourceScope = sourceScope
        self.imageMode = imageMode
    }
}

public struct CardGenerationResult: Sendable {
    public var runMetadata: GenerationRunMetadata?
    public var bookBrief: BookBrief
    public var cards: [DeckCard]
    public var warnings: [GenerationWarning]

    public init(
        runMetadata: GenerationRunMetadata? = nil,
        bookBrief: BookBrief,
        cards: [DeckCard],
        warnings: [GenerationWarning] = []
    ) {
        self.runMetadata = runMetadata
        self.bookBrief = bookBrief
        self.cards = cards
        self.warnings = warnings
    }
}
