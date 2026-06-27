import Foundation

public protocol CardGeneratorResolving: Sendable {
    func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability
    func generator(for provider: CardGenerationProvider) -> any CardGenerator
}

public struct DefaultCardGeneratorResolver: CardGeneratorResolving {
    private let commandAvailability: LocalCommandAvailability

    public init(commandAvailability: LocalCommandAvailability = LocalCommandAvailability()) {
        self.commandAvailability = commandAvailability
    }

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        if let cliAvailability = commandAvailability.availability(for: provider) {
            return cliAvailability
        }

        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return FoundationModelAvailability.current()
        case .claudeCLI:
            return .available("Claude CLI ready")
        case .codexCLI:
            return .available("Codex CLI ready")
        }
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        switch provider {
        case .fixture:
            return FixtureCardGenerator()
        case .foundationModels:
            let availability = availability(for: provider)
            guard availability.isAvailable else {
                return UnavailableCardGenerator(message: availability.message)
            }

            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                return FoundationModelCardGenerator()
            }
            #endif

            return UnavailableCardGenerator(message: availability.message)
        case .claudeCLI:
            let availability = availability(for: provider)
            guard availability.isAvailable else {
                return UnavailableCardGenerator(message: availability.message)
            }

            return LocalClaudeCLIGenerator()
        case .codexCLI:
            let availability = availability(for: provider)
            guard availability.isAvailable else {
                return UnavailableCardGenerator(message: availability.message)
            }

            return LocalCodexCLIGenerator()
        }
    }
}

public struct FixedCardGeneratorResolver: CardGeneratorResolving {
    private let generator: any CardGenerator
    private let availableProviders: Set<CardGenerationProvider>

    public init(generator: any CardGenerator) {
        self.init(generator: generator, availableProviders: Set(CardGenerationProvider.allCases))
    }

    public init(
        generator: any CardGenerator,
        availableProviders: Set<CardGenerationProvider>
    ) {
        self.generator = generator
        self.availableProviders = availableProviders
    }

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        guard availableProviders.contains(provider) else {
            return .unavailable("\(provider.displayName) generator is not connected yet")
        }

        return .available("\(provider.displayName) ready")
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        guard availableProviders.contains(provider) else {
            return UnavailableCardGenerator(message: availability(for: provider).message)
        }

        return generator
    }
}

public struct UnavailableCardGenerator: CardGenerator {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        throw CardGenerationError.unavailable(message)
    }
}
