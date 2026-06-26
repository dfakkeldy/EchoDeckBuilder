import Foundation

public struct AnkiTSVExporter: Sendable {
    public init() {}

    public func export(cards: [DeckCard]) -> String {
        let rows = cards
            .filter { $0.reviewState == .accepted }
            .map { card in
                [
                    sanitize(frontText(for: card)),
                    sanitize(card.backText),
                    card.tags.map(normalizeTag).joined(separator: " "),
                    card.sourceAnchor.suffix
                ].joined(separator: "\t")
            }

        guard !rows.isEmpty else {
            return ""
        }

        return rows.joined(separator: "\n") + "\n"
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func frontText(for card: DeckCard) -> String {
        if card.kind == .cloze, let clozeText = card.clozeText, !clozeText.isEmpty {
            return clozeText
        }

        return card.frontText
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
    }
}
