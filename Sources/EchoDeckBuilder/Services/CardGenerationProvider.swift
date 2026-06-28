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

    public var disclosureMessage: String? {
        switch self {
        case .fixture:
            return "Fixture generation stays local and deterministic."
        case .foundationModels:
            return "Foundation Models runs on device when Apple Intelligence is available."
        case .claudeCLI:
            return "Claude CLI may send selected EPUB text through your configured Claude account."
        case .codexCLI:
            return "Codex CLI may send selected EPUB text through your configured Codex/OpenAI account."
        }
    }
}
