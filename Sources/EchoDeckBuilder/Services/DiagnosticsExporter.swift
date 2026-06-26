import Foundation

public struct DiagnosticsExporter: Sendable {
    public init() {}

    public func export(sections: [BookSection], cards: [DeckCard]) -> String {
        let summary = EchoDeckJSONExporter().summary(for: cards)
        let anchors = sections.map { "\($0.anchor.suffix) \($0.heading)" }.joined(separator: "\n")

        return """
        EchoDeckBuilder Diagnostics
        Sections: \(sections.count)
        Cards: \(summary.totalCards)
        Accepted: \(summary.acceptedCount)
        Draft: \(summary.draftCount)
        Rejected: \(summary.rejectedCount)
        Exported: \(summary.exportedCount)
        Source Anchored: \(summary.sourceAnchoredCount)

        Anchors:
        \(anchors)
        """
    }
}
