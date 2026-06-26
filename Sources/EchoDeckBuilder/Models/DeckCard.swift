import Foundation

public enum CardKind: String, Codable, CaseIterable, Sendable {
    case basic
    case cloze
}

public enum CardReviewState: String, Codable, CaseIterable, Sendable {
    case draft
    case accepted
    case rejected
}

public struct CardAIMetadata: Codable, Hashable, Sendable {
    public var importance: Double
    public var confidence: Double
    public var rationale: String

    public init(importance: Double, confidence: Double, rationale: String) {
        self.importance = importance
        self.confidence = confidence
        self.rationale = rationale
    }
}

public struct DeckCard: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sectionID: BookSection.ID
    public var frontText: String
    public var backText: String
    public var kind: CardKind
    public var tags: [String]
    public var sourceAnchor: SourceAnchor
    public var reviewState: CardReviewState
    public var visual: CardVisual?
    public var clozeText: String?
    public var aiMetadata: CardAIMetadata?

    public init(
        id: UUID = UUID(),
        sectionID: BookSection.ID,
        frontText: String,
        backText: String,
        kind: CardKind,
        tags: [String] = [],
        sourceAnchor: SourceAnchor,
        reviewState: CardReviewState = .draft,
        visual: CardVisual? = nil,
        clozeText: String? = nil,
        aiMetadata: CardAIMetadata? = nil
    ) {
        self.id = id
        self.sectionID = sectionID
        self.frontText = frontText
        self.backText = backText
        self.kind = kind
        self.tags = tags
        self.sourceAnchor = sourceAnchor
        self.reviewState = reviewState
        self.visual = visual
        self.clozeText = clozeText
        self.aiMetadata = aiMetadata
    }
}
