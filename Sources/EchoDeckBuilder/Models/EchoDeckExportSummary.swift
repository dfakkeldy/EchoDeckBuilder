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

public struct EchoDeckExportReadiness: Equatable, Sendable {
    public var canExport: Bool
    public var message: String

    public static let missingTargetMediaID = EchoDeckExportReadiness(
        canExport: false,
        message: "Set the exact Echo target media ID before export"
    )

    public static let missingAcceptedCards = EchoDeckExportReadiness(
        canExport: false,
        message: "Accept at least one card before export"
    )

    public static func ready(acceptedCount: Int) -> EchoDeckExportReadiness {
        EchoDeckExportReadiness(
            canExport: true,
            message: "Ready to export \(acceptedCount) accepted Echo card\(acceptedCount == 1 ? "" : "s")"
        )
    }
}
