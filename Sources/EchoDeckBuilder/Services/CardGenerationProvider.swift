import Foundation

public enum CardGenerationProvider: String, CaseIterable, Identifiable, Sendable {
    case fixture
    case foundationModels

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .fixture:
            return "Fixture"
        case .foundationModels:
            return "Foundation Models"
        }
    }
}
