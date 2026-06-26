import Foundation

public enum GenerationSourceScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case selectedBook = "selected-book"
    case selectedSection = "selected-section"

    public var id: String { rawValue }
}

public struct CardGenerationRequest: Sendable {
    public var sections: [BookSection]
    public var acceptedCards: [DeckCard]
    public var settings: GenerationSettings
    public var sourceScope: GenerationSourceScope
    public var targetMediaID: String?

    public init(
        sections: [BookSection],
        acceptedCards: [DeckCard] = [],
        settings: GenerationSettings = GenerationSettings(),
        sourceScope: GenerationSourceScope = .selectedBook,
        targetMediaID: String? = nil
    ) {
        self.sections = sections
        self.acceptedCards = acceptedCards
        self.settings = settings
        self.sourceScope = sourceScope
        self.targetMediaID = targetMediaID
    }

    public var runMetadata: GenerationRunMetadata {
        GenerationRunMetadata(
            provider: settings.provider.rawValue,
            model: settings.model,
            sourceScope: sourceScope.rawValue,
            imageMode: settings.imageMode.rawValue
        )
    }
}
