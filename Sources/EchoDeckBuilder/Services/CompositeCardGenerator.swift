import Foundation

public struct CompositeCardGenerator: CardGenerator {
    private let fixture: any CardGenerator
    private let claudeCLI: any CardGenerator
    private let codexCLI: (any CardGenerator)?

    public init(
        fixture: any CardGenerator = FixtureCardGenerator(),
        claudeCLI: any CardGenerator = LocalClaudeCLIGenerator(),
        codexCLI: (any CardGenerator)? = LocalCodexCLIGenerator()
    ) {
        self.fixture = fixture
        self.claudeCLI = claudeCLI
        self.codexCLI = codexCLI
    }

    public func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        switch request.settings.provider {
        case .fixture:
            return try await fixture.generateCards(for: request)
        case .foundationModels:
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                return try await FoundationModelCardGenerator().generateCards(for: request)
            }
            #endif

            throw CardGenerationError.unavailable(FoundationModelAvailability.current().message)
        case .claudeCLI:
            return try await claudeCLI.generateCards(for: request)
        case .codexCLI:
            if let codexCLI {
                return try await codexCLI.generateCards(for: request)
            } else {
                throw CompositeCardGeneratorError.codexGeneratorUnavailable
            }
        }
    }
}

public enum CompositeCardGeneratorError: Error, LocalizedError, Sendable {
    case codexGeneratorUnavailable

    public var errorDescription: String? {
        switch self {
        case .codexGeneratorUnavailable:
            "Codex CLI generation is not configured yet."
        }
    }
}
