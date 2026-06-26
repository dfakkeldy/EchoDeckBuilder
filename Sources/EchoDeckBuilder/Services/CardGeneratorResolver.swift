import Foundation

public protocol CardGeneratorResolving: Sendable {
    func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability
    func generator(for provider: CardGenerationProvider) -> any CardGenerator
}

public struct DefaultCardGeneratorResolver: CardGeneratorResolving {
    public init() {}

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return FoundationModelAvailability.current()
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

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        throw CardGenerationError.unavailable(message)
    }
}
