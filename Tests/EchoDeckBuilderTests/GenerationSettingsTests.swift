import XCTest
@testable import EchoDeckBuilder

final class GenerationSettingsTests: XCTestCase {
    func testProviderDisclosureMessagesDistinguishLocalAndNonLocalGeneration() {
        XCTAssertEqual(
            CardGenerationProvider.fixture.disclosureMessage,
            "Fixture generation stays local and deterministic."
        )
        XCTAssertEqual(
            CardGenerationProvider.foundationModels.disclosureMessage,
            "Foundation Models runs on device when Apple Intelligence is available."
        )
        XCTAssertEqual(
            CardGenerationProvider.claudeCLI.disclosureMessage,
            "Claude CLI may send selected EPUB text through your configured Claude account."
        )
        XCTAssertEqual(
            CardGenerationProvider.codexCLI.disclosureMessage,
            "Codex CLI may send selected EPUB text through your configured Codex/OpenAI account."
        )
    }
}
