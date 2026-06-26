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
            settings: GenerationSettings(provider: .codexCLI, model: "gpt-5.4", batchSize: 1)
        ))

        let invocations = await runner.recordedInvocations()
        XCTAssertEqual(invocations.count, 3)
        XCTAssertEqual(invocations[0].executable, "/usr/bin/env")
        XCTAssertEqual(Array(invocations[0].arguments.prefix(2)), ["codex", "exec"])
        XCTAssertTrue(invocations[0].arguments.contains("--ephemeral"))
        XCTAssertTrue(invocations[0].arguments.contains("--ignore-user-config"))
        XCTAssertTrue(invocations[0].arguments.contains("--ignore-rules"))
        XCTAssertTrue(invocations[0].arguments.contains("--skip-git-repo-check"))
        XCTAssertTrue(invocations[0].arguments.contains("--sandbox"))
        XCTAssertEqual(codexArgument(after: "--sandbox", in: invocations[0]), "read-only")
        XCTAssertEqual(codexArgument(after: "-c", in: invocations[0]), "approval_policy=\"never\"")
        XCTAssertEqual(codexArgument(after: "--model", in: invocations[0]), "gpt-5.4")
        XCTAssertTrue(invocations[0].arguments.contains("--output-schema"))
        XCTAssertNotNil(invocations[0].workingDirectory)
        XCTAssertEqual(codexArgument(after: "-C", in: invocations[0]), invocations[0].workingDirectory?.path)
        XCTAssertEqual(invocations[0].arguments.last, "-")
        XCTAssertTrue(invocations[0].standardInput.contains("<source-outline>"))
        XCTAssertTrue(invocations[1].standardInput.contains(#"<source-block anchor="s1-b1">"#))
        XCTAssertFalse(invocations[1].standardInput.contains(#"<source-block anchor="s1-b2">"#))
        XCTAssertTrue(invocations[2].standardInput.contains(#"<source-block anchor="s1-b2">"#))
        XCTAssertFalse(invocations[2].standardInput.contains(#"<source-block anchor="s1-b1">"#))

        let schemaSnapshots = await runner.recordedSchemaSnapshots()
        XCTAssertEqual(schemaSnapshots.count, 3)
        let schemaPath = try XCTUnwrap(schemaSnapshots.first?.path)
        let outputSchemaIndex = try XCTUnwrap(invocations[0].arguments.firstIndex(of: "--output-schema"))
        XCTAssertEqual(invocations[0].arguments[outputSchemaIndex + 1], schemaPath)
        XCTAssertEqual(invocations[0].workingDirectory?.path, URL(fileURLWithPath: schemaPath).deletingLastPathComponent().path)
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.path == schemaPath })
        XCTAssertTrue(schemaSnapshots.allSatisfy(\.fileExistsDuringRun))
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.contents.contains("\"bookBrief\"") })
        XCTAssertTrue(schemaSnapshots.allSatisfy { $0.contents.contains("\"warnings\"") })

        XCTAssertFalse(FileManager.default.fileExists(atPath: schemaPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: URL(fileURLWithPath: schemaPath).deletingLastPathComponent().path))

        XCTAssertEqual(result.bookBrief.summary, "Brief")
        XCTAssertEqual(result.runMetadata?.provider, "codexCLI")
        XCTAssertEqual(result.runMetadata?.model, "gpt-5.4")
        XCTAssertEqual(result.cards.map(\.frontText), ["Front 1", "Front 2"])
        XCTAssertEqual(result.cards.map(\.sourceAnchor.suffix), ["s1-b1", "s1-b2"])
        XCTAssertEqual(result.warnings.map(\.message), ["brief warning", "batch 1 warning", "batch 2 warning"])
    }

    func testCodexGeneratorCleansTemporaryDirectoryWhenSchemaDataThrows() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "EchoDeckBuilder-CodexCLITests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let generator = LocalCodexCLIGenerator(
            processRunner: RecordingCodexProcessRunner(outputs: []),
            temporaryDirectory: temporaryDirectory,
            outputSchemaData: { throw SchemaDataFailure() }
        )

        do {
            _ = try await generator.generateCards(for: CardGenerationRequest(sections: []))
            XCTFail("Expected schema data failure.")
        } catch is SchemaDataFailure {
            let remainingItems = try FileManager.default.contentsOfDirectory(
                at: temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            XCTAssertEqual(remainingItems, [])
        } catch {
            XCTFail("Expected SchemaDataFailure, got \(error).")
        }
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

private struct SchemaDataFailure: Error {}

private func codexArgument(after flag: String, in invocation: ProcessInvocation) -> String? {
    guard let index = invocation.arguments.firstIndex(of: flag),
          invocation.arguments.indices.contains(index + 1)
    else {
        return nil
    }
    return invocation.arguments[index + 1]
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
