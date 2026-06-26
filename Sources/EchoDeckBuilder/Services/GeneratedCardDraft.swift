import Foundation

public struct GeneratedCardDraft: Equatable, Sendable {
    public var frontText: String
    public var backText: String
    public var kind: CardKind
    public var tags: [String]

    public init(frontText: String, backText: String, kind: CardKind, tags: [String]) {
        self.frontText = frontText
        self.backText = backText
        self.kind = kind
        self.tags = tags
    }
}

public enum GeneratedCardDraftMapper {
    public static func deckCard(from draft: GeneratedCardDraft, section: BookSection) -> DeckCard? {
        let frontText = draft.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let backText = draft.backText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !frontText.isEmpty, !backText.isEmpty else {
            return nil
        }

        return DeckCard(
            sectionID: section.id,
            frontText: frontText,
            backText: backText,
            kind: draft.kind,
            tags: mergedTags(from: draft.tags),
            sourceAnchor: section.anchor
        )
    }

    private static func mergedTags(from generatedTags: [String]) -> [String] {
        var tags: [String] = []
        for tag in ["generated", "foundation-models"] + generatedTags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !tags.contains(normalized) else {
                continue
            }
            tags.append(normalized)
        }
        return tags
    }
}
