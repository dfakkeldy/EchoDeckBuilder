import Foundation

public struct CardGenerationRequest: Sendable {
    public var sections: [BookSection]
    public var acceptedCards: [DeckCard]
    public var settings: GenerationSettings

    public init(
        sections: [BookSection],
        acceptedCards: [DeckCard] = [],
        settings: GenerationSettings = GenerationSettings()
    ) {
        self.sections = sections
        self.acceptedCards = acceptedCards
        self.settings = settings
    }
}
