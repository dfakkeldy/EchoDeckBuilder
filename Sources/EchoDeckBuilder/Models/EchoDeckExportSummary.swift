import Foundation

public struct EchoDeckExportSummary: Equatable, Sendable {
    public var totalCards: Int
    public var acceptedCount: Int
    public var draftCount: Int
    public var rejectedCount: Int
    public var exportedCount: Int
    public var sourceAnchoredCount: Int

    public init(
        totalCards: Int,
        acceptedCount: Int,
        draftCount: Int,
        rejectedCount: Int,
        exportedCount: Int,
        sourceAnchoredCount: Int
    ) {
        self.totalCards = totalCards
        self.acceptedCount = acceptedCount
        self.draftCount = draftCount
        self.rejectedCount = rejectedCount
        self.exportedCount = exportedCount
        self.sourceAnchoredCount = sourceAnchoredCount
    }
}
