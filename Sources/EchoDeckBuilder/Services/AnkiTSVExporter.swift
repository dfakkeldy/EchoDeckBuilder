import Foundation

public struct AnkiTSVExporter: Sendable {
    public init() {}

    public func export(cards: [DeckCard]) -> String {
        cards
            .filter { $0.reviewState == .accepted }
            .map { card in
                [
                    sanitize(card.frontText),
                    sanitize(card.backText),
                    card.tags.map(normalizeTag).joined(separator: " "),
                    card.sourceAnchor.suffix
                ].joined(separator: "\t")
            }
            .joined(separator: "\n") + "\n"
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
    }
}
