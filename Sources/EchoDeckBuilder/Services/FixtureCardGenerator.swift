import Foundation

public protocol CardGenerator: Sendable {
    func generateCards(for sections: [BookSection]) async throws -> [DeckCard]
}

public struct FixtureCardGenerator: CardGenerator {
    public init() {}

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        sections.map { section in
            let concept = section.heading == "Untitled Section" ? "this section" : section.heading
            let summary = section.text.split(separator: ".").first.map(String.init) ?? section.text
            return DeckCard(
                sectionID: section.id,
                frontText: "What is the key idea in \(concept)?",
                backText: summary,
                kind: .basic,
                tags: ["generated", "fixture"],
                sourceAnchor: section.anchor
            )
        }
    }
}
