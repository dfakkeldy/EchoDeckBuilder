import XCTest
@testable import EchoDeckBuilder

final class CardGenerationProviderTests: XCTestCase {
    func testProviderDisplayNamesAreStable() {
        XCTAssertEqual(CardGenerationProvider.fixture.displayName, "Fixture")
        XCTAssertEqual(CardGenerationProvider.foundationModels.displayName, "Foundation Models")
        XCTAssertEqual(CardGenerationProvider.allCases, [.fixture, .foundationModels])
    }

    func testAvailabilityFactoriesPreserveMessages() {
        let available = CardGenerationAvailability.available("Fixture generator ready")
        let unavailable = CardGenerationAvailability.unavailable("Foundation Models requires macOS 26+")

        XCTAssertTrue(available.isAvailable)
        XCTAssertEqual(available.message, "Fixture generator ready")
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(unavailable.message, "Foundation Models requires macOS 26+")
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
}

private struct StaticCardGenerator: CardGenerator {
    let cards: [DeckCard]

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        cards
    }
}
