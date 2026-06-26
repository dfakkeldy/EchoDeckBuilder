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
    static let maximumFrontTextCharacters = 240
    static let maximumBackTextCharacters = 480

    public static func deckCard(from draft: GeneratedCardDraft, section: BookSection) -> DeckCard? {
        guard
            let frontText = normalizedText(
                from: draft.frontText,
                maximumCharacters: maximumFrontTextCharacters
            ),
            let backText = normalizedText(
                from: draft.backText,
                maximumCharacters: maximumBackTextCharacters
            )
        else {
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

    private static func normalizedText(from text: String, maximumCharacters: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumCharacters else {
            return nil
        }
        return trimmed
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
