import Foundation
import XCTest
@testable import EchoDeckBuilder

final class LocalCodexCLIGeneratorTests: XCTestCase {
    func testCodexGeneratorUsesSchemaFileAndReturnsValidatedCards() async throws {
        let sections = try [
            makeSection(spineIndex: 1, blockIndex: 1, suffix: "s1-b1", heading: "Context", text: "Context matters."),
            makeSection(spineIndex: 1, blockIndex: 2, suffix: "s1-b2", heading: "Practice", text: "Practice compounds.")
        ]
        let runner = RecordingCodexProcessRunner(outputs: [
            try makeOutput(cards: [], warnings: ["brief warning"]),
            try makeOutput(cards: [
                AIModelOutput.Card(
                    sourceAnchor: "s1-b1",
                    kind: "basic",
                    frontText: "Front 1",
                    backText: "Back 1",
                    clozeText: nil,
                    tags: ["tag-1"],
                    importance: 0.8,
                    confidence: 0.9,
                    rationale: "Central point.",
                    visual: nil
                )
            ], warnings: ["batch 1 warning"]),
            try makeOutput(cards: [
                AIModelOutput.Card(
                    sourceAnchor: "s1-b2",
                    kind: "basic",
                    frontText: "Front 2",
                    backText: "Back 2",
                    clozeText: nil,
                    tags: ["tag-2"],
                    importance: 0.7,
                    confidence: 0.85,
                    rationale: "Follow-up point.",
                    visual: nil
                )
            ], warnings: ["batch 2 warning"])
        ])
        let generator = LocalCodexCLIGenerator(processRunner: runner, batcher: GenerationBatcher())

        let result = try await generator.generateCards(for: CardGenerationRequest(
            sections: sections,
            settings: GenerationSettings(provider: .codexCLI, batchSize: 1)
        ))

        let invocations = await runner.recordedInvocations()
        XCTAssertEqual(invocations.count, 3)
        XCTAssertEqual(Array(invocations[0].arguments.prefix(2)), ["codex", "exec"])
        XCTAssertTrue(invocations[0].arguments.contains("--ephemeral"))
        XCTAssertTrue(invocations[0].arguments.contains("--sandbox"))
        XCTAssertTrue(invocations[0].arguments.contains("read-only"))
        XCTAssertTrue(invocations[0].arguments.contains("--output-schema"))
        XCTAssertEqual(invocations[0].arguments.last, "-")
        XCTAssertTrue(invocations[0].standardInput.contains("<source-outline>"))
        XCTAssertTrue(invocations[1].standardInput.contains(#"<source-block anchor="s1-b1">"#))
        XCTAssertFalse(invocations[1].standardInput.contains(#"<source-block anchor="s1-b2">"#))
        XCTAssertTrue(invocations[2].standardInput.contains(#"<source-block anchor="s1-b2">"#))
        XCTAssertFalse(invocations[2].standardInput.contains(#"<source-block anchor="s1-b1">"#))

        let schemaSnapshots = await runner.recordedSchemaSnapshots()
        XCTAssertEqual(schemaSnapshots.count, 3)
        let schemaPath = try XCTUnwrap(schemaSnapshots.first?.path)
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.path == schemaPath })
        XCTAssertTrue(schemaSnapshots.allSatisfy(\.fileExistsDuringRun))
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.contents.contains("\"bookBrief\"") })
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.contents.contains("\"warnings\"") })

        XCTAssertFalse(FileManager.default.fileExists(atPath: schemaPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: URL(fileURLWithPath: schemaPath).deletingLastPathComponent().path))

        XCTAssertEqual(result.bookBrief.summary, "Brief")
        XCTAssertEqual(result.cards.map(\.frontText), ["Front 1", "Front 2"])
        XCTAssertEqual(result.cards.map(\.sourceAnchor.suffix), ["s1-b1", "s1-b2"])
        XCTAssertEqual(result.warnings.map(\.message), ["brief warning", "batch 1 warning", "batch 2 warning"])
    }

    private func makeSection(
        spineIndex: Int,
        blockIndex: Int,
        suffix: String,
        heading: String,
        text: String
    ) throws -> BookSection {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: suffix))
        return BookSection(
            spineIndex: spineIndex,
            blockIndex: blockIndex,
            heading: heading,
            text: text,
            anchor: anchor
        )
    }

    private func makeOutput(cards: [AIModelOutput.Card], warnings: [String]) throws -> ProcessResult {
        let output = AIModelOutput(
            run: .init(provider: "codex-cli", model: "default", sourceScope: "selected-book", imageMode: "off"),
            bookBrief: .init(
                summary: "Brief",
                themes: ["theme"],
                keyConcepts: ["concept"],
                argumentFlow: ["flow"],
                skipAreas: []
            ),
            cards: cards,
            warnings: warnings
        )
        let data = try JSONEncoder().encode(output)
        return ProcessResult(standardOutput: String(decoding: data, as: UTF8.self), standardError: "", terminationStatus: 0)
    }
}

private struct SchemaSnapshot: Sendable {
    let path: String
    let contents: String
    let fileExistsDuringRun: Bool
}

private actor RecordingCodexProcessRunner: ProcessRunning {
    private var outputs: [ProcessResult]
    private var invocations: [ProcessInvocation] = []
    private var schemaSnapshots: [SchemaSnapshot] = []

    init(outputs: [ProcessResult]) {
        self.outputs = outputs
    }

    func run(_ invocation: ProcessInvocation) async throws -> ProcessResult {
        invocations.append(invocation)

        if let schemaIndex = invocation.arguments.firstIndex(of: "--output-schema"),
           invocation.arguments.indices.contains(schemaIndex + 1) {
            let schemaPath = invocation.arguments[schemaIndex + 1]
            let schemaURL = URL(fileURLWithPath: schemaPath)
            let contents = try String(contentsOf: schemaURL, encoding: .utf8)
            schemaSnapshots.append(SchemaSnapshot(
                path: schemaPath,
                contents: contents,
                fileExistsDuringRun: FileManager.default.fileExists(atPath: schemaPath)
            ))
        }

        return outputs.removeFirst()
    }

    func recordedInvocations() -> [ProcessInvocation] {
        invocations
    }

    func recordedSchemaSnapshots() -> [SchemaSnapshot] {
        schemaSnapshots
    }
}
