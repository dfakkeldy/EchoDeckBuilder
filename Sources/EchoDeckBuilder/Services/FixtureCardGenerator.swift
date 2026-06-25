import Foundation

public protocol CardGenerator: Sendable {
    func generateCards(for sections: [BookSection]) async throws -> [DeckCard]
}

public struct FixtureCardGenerator: CardGenerator {
    public init() {}

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        sections.map { section in
            let concept = Self.concept(from: section)
            let backText = Self.makeBackText(from: section.text, section: section)
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

    private static func concept(from section: BookSection) -> String {
        let heading = section.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        return heading.isEmpty || heading == "Untitled Section" ? "this section" : heading.lowercased()
    }

    private static func makeBackText(from body: String, section: BookSection) -> String {
        let meaningfulKeywords = keywords(from: body)
        if !meaningfulKeywords.isEmpty {
            return bodyAwareBackText(terms: meaningfulKeywords, section: section)
        }

        let fallbackTokens = normalizedTokens(from: body)
        if !fallbackTokens.isEmpty {
            return bodyAwareBackText(terms: fallbackTokens, section: section)
        }

        return "This anchored block has no extractable body terms, so review should inspect the source passage."
    }

    private static func bodyAwareBackText(terms: [String], section: BookSection) -> String {
        let termList = terms.prefix(4).joined(separator: ", ")
        return "Body terms: \(termList). Review section \(section.spineIndex), block \(section.blockIndex)."
    }

    private static func keywords(from text: String) -> [String] {
        normalizedTokens(from: text).filter { !stopWords.contains($0) }
    }

    private static func normalizedTokens(from text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
        "in", "into", "is", "it", "of", "on", "or", "that", "the", "this",
        "to", "with", "your", "you", "we", "our", "their", "they", "them",
        "was", "were", "will", "would", "can", "could", "should", "may",
        "might", "has", "have", "had", "do", "does", "did", "using", "use",
        "good", "useful", "section", "block", "preserve", "preserves",
        "make", "made", "more", "less", "reliable", "outputs", "output"
    ]
}
