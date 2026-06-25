import Foundation

public protocol CardGenerator: Sendable {
    func generateCards(for sections: [BookSection]) async throws -> [DeckCard]
}

public struct FixtureCardGenerator: CardGenerator {
    public init() {}

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        sections.map { section in
            let concept = Self.concept(from: section)
            let keywords = Self.keywords(from: section)
            let backText = Self.makeBackText(keywords: keywords, concept: concept, section: section)
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

    private static func keywords(from section: BookSection) -> [String] {
        let tokens = tokenize(section.heading) + tokenize(section.text)
        var keywords: [String] = []
        var seen = Set<String>()

        for token in tokens where !stopWords.contains(token) && seen.insert(token).inserted {
            keywords.append(token)
            if keywords.count == 4 {
                break
            }
        }

        return keywords
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func makeBackText(keywords: [String], concept: String, section: BookSection) -> String {
        let keywordList = keywords.prefix(4).joined(separator: ", ")
        let keywordPhrase = keywordList.isEmpty ? concept : keywordList
        return "This section connects \(keywordPhrase) with \(concept) in section \(section.spineIndex), block \(section.blockIndex), giving a concise review target without quoting the source."
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
