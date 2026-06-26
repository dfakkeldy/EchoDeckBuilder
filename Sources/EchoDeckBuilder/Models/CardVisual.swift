import Foundation

public enum CardVisualPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public struct CardVisual: Codable, Hashable, Sendable {
    public var priority: CardVisualPriority
    public var imagePrompt: String
    public var altText: String

    public init(priority: CardVisualPriority, imagePrompt: String, altText: String) {
        self.priority = priority
        self.imagePrompt = imagePrompt
        self.altText = altText
    }
}
