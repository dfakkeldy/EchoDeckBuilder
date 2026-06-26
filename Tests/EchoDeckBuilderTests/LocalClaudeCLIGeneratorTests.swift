import XCTest
@testable import EchoDeckBuilder

final class LocalClaudeCLIGeneratorTests: XCTestCase {
    func testClaudeGeneratorRunsBriefAndBatchPrompts() async throws {
        let section = try makeSection()
        let runner = RecordingProcessRunner(outputs: [
            try makeOutput(cards: []),
            try makeOutput(cards: [
                AIModelOutput.Card(
                    sourceAnchor: "s1-b1",
                    kind: "basic",
                    frontText: "Front",
                    backText: "Back",
                    clozeText: nil,
                    tags: ["tag"],
                    importance: 0.8,
                    confidence: 0.9,
                    rationale: "Central point.",
                    visual: nil
                )
            ])
        ])
        let generator = LocalClaudeCLIGenerator(processRunner: runner)

        let result = try await generator.generateCards(for: CardGenerationRequest(
            sections: [section],
            settings: GenerationSettings(provider: .claudeCLI)
        ))

        let invocations = await runner.recordedInvocations()
        XCTAssertEqual(invocations.count, 2)
        XCTAssertEqual(invocations[0].executable, "/usr/bin/env")
        XCTAssertTrue(invocations[0].arguments.contains("claude"))
        XCTAssertTrue(invocations[0].arguments.contains("-p"))
        XCTAssertTrue(invocations[0].arguments.contains("--json-schema"))
        XCTAssertTrue(invocations[0].standardInput.contains("<source-outline>"))
        XCTAssertTrue(invocations[1].standardInput.contains("<batch-source>"))
        XCTAssertEqual(result.cards.count, 1)
        XCTAssertEqual(result.cards[0].sourceAnchor.suffix, "s1-b1")
    }

    func testCompositeGeneratorDispatchesToFixtureByDefault() async throws {
        let section = try makeSection()
        let result = try await CompositeCardGenerator().generateCards(for: CardGenerationRequest(sections: [section]))

        XCTAssertEqual(result.cards.count, 1)
        XCTAssertEqual(result.cards[0].tags, ["generated", "fixture"])
    }

    private func makeSection() throws -> BookSection {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        return BookSection(spineIndex: 1, blockIndex: 1, heading: "Context", text: "Context matters.", anchor: anchor)
    }

    private func makeOutput(cards: [AIModelOutput.Card]) throws -> ProcessResult {
        let output = AIModelOutput(
            run: .init(provider: "claude-cli", model: "default", sourceScope: "selected-book", imageMode: "off"),
            bookBrief: .init(summary: "Brief", themes: ["theme"], keyConcepts: ["concept"], argumentFlow: ["flow"], skipAreas: []),
            cards: cards,
            warnings: []
        )
        let data = try JSONEncoder().encode(output)
        return ProcessResult(standardOutput: String(decoding: data, as: UTF8.self), standardError: "", terminationStatus: 0)
    }
}

private actor RecordingProcessRunner: ProcessRunning {
    private var outputs: [ProcessResult]
    private var invocations: [ProcessInvocation] = []

    init(outputs: [ProcessResult]) {
        self.outputs = outputs
    }

    func run(_ invocation: ProcessInvocation) async throws -> ProcessResult {
        invocations.append(invocation)
        return outputs.removeFirst()
    }

    func recordedInvocations() -> [ProcessInvocation] {
        invocations
    }
}
