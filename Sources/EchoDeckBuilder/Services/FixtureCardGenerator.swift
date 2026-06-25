import Foundation

public protocol CardGenerator: Sendable {
    func generateCards(for sections: [BookSection]) async throws -> [DeckCard]
}

public struct FixtureCardGenerator: CardGenerator {
    public init() {}

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        sections.map { section in
            let concept = section.heading == "Untitled Section" ? "this section" : section.heading
            let backText = Self.makeBackText(from: section, concept: concept)
            return DeckCard(
                sectionID: section.id,
                frontText: "What is the key idea in \(concept)?",
                backText: backText,
                kind: .basic,
                tags: ["generated", "fixture"],
                sourceAnchor: section.anchor
            )
        }
    }

    private static func makeBackText(from section: BookSection, concept: String) -> String {
        """
        Paraphrase the core idea from "\(concept)" in section \(section.spineIndex), block \(section.blockIndex).
        """
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
