import Foundation

public struct EchoDeckDocument: Codable, Sendable {
    public var deckName: String
    public var targetMediaID: String
    public var cards: [EchoDeckCardDocument]
}

public struct EchoDeckCardDocument: Codable, Sendable {
    public var frontText: String
    public var backText: String
    public var triggerTiming: String
    public var sourceAnchor: String
}
