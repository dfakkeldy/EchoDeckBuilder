import Foundation

public struct LocalCommandAvailability: Sendable {
    public var isCommandAvailable: @Sendable (String) -> Bool

    public init(isCommandAvailable: @escaping @Sendable (String) -> Bool = Self.defaultLookup) {
        self.isCommandAvailable = isCommandAvailable
    }

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability? {
        switch provider {
        case .claudeCLI:
            return isCommandAvailable("claude")
                ? .available("Claude CLI ready")
                : .unavailable("Install and authenticate Claude CLI to use this provider")
        case .codexCLI:
            return isCommandAvailable("codex")
                ? .available("Codex CLI ready")
                : .unavailable("Install and authenticate Codex CLI to use this provider")
        case .fixture, .foundationModels:
            return nil
        }
    }

    public static func defaultLookup(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
