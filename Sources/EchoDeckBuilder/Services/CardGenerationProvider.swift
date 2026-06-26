import Foundation

public enum CardGenerationProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixture
    case foundationModels
    case claudeCLI
    case codexCLI

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .fixture:
            return "Fixture"
        case .foundationModels:
            return "Foundation Models"
        case .claudeCLI:
            return "Claude CLI"
        case .codexCLI:
            return "Codex CLI"
        }
    }
}
