import Foundation

public struct DiagnosticsExporter: Sendable {
    public init() {}

    public func export(sections: [BookSection], cards: [DeckCard]) -> String {
        let summary = EchoDeckJSONExporter().summary(for: cards)
        let anchors = sections.map { "\($0.anchor.suffix) \($0.heading)" }.joined(separator: "\n")

        let visualPrompts: [String] = cards.compactMap { card -> String? in
            guard let visual = card.visual else { return nil }
            return "- \(card.sourceAnchor.suffix) | priority: \(visual.priority.rawValue) | prompt: \(visual.imagePrompt)"
        }

        let visualPromptLines = visualPrompts.joined(separator: "\n")
        let visualPromptSection = visualPromptLines.isEmpty ? "None" : visualPromptLines

        return """
        EchoDeckBuilder Diagnostics
        Sections: \(sections.count)
        Cards: \(summary.totalCards)
        Accepted: \(summary.acceptedCount)
        Draft: \(summary.draftCount)
        Rejected: \(summary.rejectedCount)
        Exported: \(summary.exportedCount)
        Source Anchored: \(summary.sourceAnchoredCount)
        Visual Prompt Count: \(visualPrompts.count)

        Anchors:
        \(anchors)

        Visual Prompt Metadata:
        \(visualPromptSection)
        """
    }
}
