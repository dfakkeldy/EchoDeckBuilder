import Foundation

public struct DiagnosticsExporter: Sendable {
    public init() {}

    public func export(sections: [BookSection], cards: [DeckCard]) -> String {
        let accepted = cards.filter { $0.reviewState == .accepted }.count
        let rejected = cards.filter { $0.reviewState == .rejected }.count
        let draft = cards.filter { $0.reviewState == .draft }.count
        let anchors = sections.map { "\($0.anchor.suffix) \($0.heading)" }.joined(separator: "\n")

        return """
        EchoDeckBuilder Diagnostics
        Sections: \(sections.count)
        Cards: \(cards.count)
        Accepted: \(accepted)
        Draft: \(draft)
        Rejected: \(rejected)

        Anchors:
        \(anchors)
        """
    }
}
