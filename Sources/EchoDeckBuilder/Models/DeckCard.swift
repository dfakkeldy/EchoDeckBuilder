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

public struct DeckCard: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sectionID: BookSection.ID
    public var frontText: String
    public var backText: String
    public var kind: CardKind
    public var tags: [String]
    public var sourceAnchor: SourceAnchor?
    public var reviewState: CardReviewState

    public init(
        id: UUID = UUID(),
        sectionID: BookSection.ID,
        frontText: String,
        backText: String,
        kind: CardKind,
        tags: [String] = [],
        sourceAnchor: SourceAnchor? = nil,
        reviewState: CardReviewState = .draft
    ) {
        self.id = id
        self.sectionID = sectionID
        self.frontText = frontText
        self.backText = backText
        self.kind = kind
        self.tags = tags
        self.sourceAnchor = sourceAnchor
        self.reviewState = reviewState
    }
}
