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
            return .unavailable("Foundation Models generator is not connected yet")
        }
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        switch provider {
        case .fixture:
            return FixtureCardGenerator()
        case .foundationModels:
            return UnavailableCardGenerator(message: availability(for: provider).message)
        }
    }
}

public struct FixedCardGeneratorResolver: CardGeneratorResolving {
    private let generator: any CardGenerator

    public init(generator: any CardGenerator) {
        self.generator = generator
    }

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        .available("\(provider.displayName) ready")
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        generator
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
