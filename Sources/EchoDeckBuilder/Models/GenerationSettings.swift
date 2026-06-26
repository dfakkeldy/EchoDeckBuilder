import Foundation

public enum ImageGenerationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case prompts

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: "Off"
        case .prompts: "Prompt suggestions"
        }
    }
}

public struct GenerationSettings: Codable, Hashable, Sendable {
    public var provider: CardGenerationProvider
    public var model: String
    public var targetCardsPerBatch: Int
    public var batchSize: Int
    public var cardKinds: [CardKind]
    public var audience: String
    public var tone: String
    public var imageMode: ImageGenerationMode

    public init(
        provider: CardGenerationProvider = .fixture,
        model: String = "default",
        targetCardsPerBatch: Int = 8,
        batchSize: Int = 12,
        cardKinds: [CardKind] = CardKind.allCases,
        audience: String = "me",
        tone: String = "clear, compact, memorable",
        imageMode: ImageGenerationMode = .off
    ) {
        self.provider = provider
        self.model = model
        self.targetCardsPerBatch = targetCardsPerBatch
        self.batchSize = batchSize
        self.cardKinds = cardKinds
        self.audience = audience
        self.tone = tone
        self.imageMode = imageMode
    }
}
