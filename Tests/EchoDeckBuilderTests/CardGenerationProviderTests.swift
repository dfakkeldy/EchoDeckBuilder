import XCTest
@testable import EchoDeckBuilder

final class CardGenerationProviderTests: XCTestCase {
    func testProviderDisplayNamesAreStable() {
        XCTAssertEqual(CardGenerationProvider.fixture.displayName, "Fixture")
        XCTAssertEqual(CardGenerationProvider.foundationModels.displayName, "Foundation Models")
        XCTAssertEqual(CardGenerationProvider.claudeCLI.displayName, "Claude CLI")
        XCTAssertEqual(CardGenerationProvider.codexCLI.displayName, "Codex CLI")
        XCTAssertEqual(CardGenerationProvider.allCases, [.fixture, .foundationModels, .claudeCLI, .codexCLI])
    }

    func testAvailabilityFactoriesPreserveMessages() {
        let available = CardGenerationAvailability.available("Fixture generator ready")
        let unavailable = CardGenerationAvailability.unavailable("Foundation Models requires macOS 26+")

        XCTAssertTrue(available.isAvailable)
        XCTAssertEqual(available.message, "Fixture generator ready")
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(unavailable.message, "Foundation Models requires macOS 26+")
    }

    func testFoundationModelAvailabilityMessagesExplainAssetStates() {
        XCTAssertEqual(
            FoundationModelAvailability.modelAssetsNotReadyMessage,
            "Apple Intelligence language model assets are downloading or not ready"
        )
        XCTAssertEqual(
            FoundationModelAvailability.modelAssetsUnavailableMessage,
            "Apple Intelligence language model assets are unavailable"
        )
    }

    func testFixedResolverAlwaysReturnsInjectedGenerator() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "A useful source block.",
            anchor: anchor
        )
        let expectedCard = DeckCard(
            sectionID: section.id,
            frontText: "Generated front",
            backText: "Generated back",
            kind: .basic,
            sourceAnchor: anchor
        )
        let resolver = FixedCardGeneratorResolver(generator: StaticCardGenerator(cards: [expectedCard]))

        XCTAssertTrue(resolver.availability(for: .fixture).isAvailable)
        XCTAssertTrue(resolver.availability(for: .foundationModels).isAvailable)

        let cards = try await resolver.generator(for: .foundationModels).generateCards(for: [section])
        XCTAssertEqual(cards, [expectedCard])
    }

    func testDefaultResolverKeepsFixtureAvailable() async throws {
        let resolver = DefaultCardGeneratorResolver()
        let availability = resolver.availability(for: .fixture)

        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(availability.message, "Fixture generator ready")

        let cards = try await resolver.generator(for: .fixture).generateCards(for: [])
        XCTAssertEqual(cards, [])
    }
}

private struct StaticCardGenerator: CardGenerator {
    let cards: [DeckCard]

    func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        CardGenerationResult(bookBrief: .fixture, cards: cards)
    }
}
