import Foundation

public struct LocalCodexCLIGenerator: CardGenerator {
    private let processRunner: any ProcessRunning
    private let promptBuilder: AIPromptPackageBuilder
    private let batcher: GenerationBatcher
    private let validator: AIModelOutputValidator
    private let temporaryDirectory: URL

    public init(
        processRunner: any ProcessRunning = LocalProcessRunner(),
        promptBuilder: AIPromptPackageBuilder = AIPromptPackageBuilder(),
        batcher: GenerationBatcher = GenerationBatcher(),
        validator: AIModelOutputValidator = AIModelOutputValidator(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.processRunner = processRunner
        self.promptBuilder = promptBuilder
        self.batcher = batcher
        self.validator = validator
        self.temporaryDirectory = temporaryDirectory
    }

    public func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        let schemaFileURL = try writeSchemaFile()
        defer { try? FileManager.default.removeItem(at: schemaFileURL.deletingLastPathComponent()) }

        let briefOutput = try await runCodex(
            prompt: promptBuilder.bookBriefPrompt(for: request),
            schemaFileURL: schemaFileURL
        )
        let briefResult = try validator.validate(briefOutput, batchSections: request.sections)
        let bookBrief = briefResult.bookBrief

        var cards: [DeckCard] = []
        var warnings = briefResult.warnings

        for batch in batcher.batches(from: request.sections, maxSectionsPerBatch: request.settings.batchSize) {
            let prompt = promptBuilder.batchPrompt(for: request, bookBrief: bookBrief, batch: batch)
            let output = try await runCodex(prompt: prompt, schemaFileURL: schemaFileURL)
            let result = try validator.validate(output, batchSections: batch)
            cards.append(contentsOf: result.cards)
            warnings.append(contentsOf: result.warnings)
        }

        return CardGenerationResult(bookBrief: bookBrief, cards: cards, warnings: warnings)
    }

    private func writeSchemaFile() throws -> URL {
        let schemaDirectory = temporaryDirectory
            .appending(path: "EchoDeckBuilder-CodexCLI-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: schemaDirectory, withIntermediateDirectories: true)

        let schemaFileURL = schemaDirectory.appending(path: "output-schema.json")
        try promptBuilder.outputSchemaData().write(to: schemaFileURL, options: .atomic)
        return schemaFileURL
    }

    private func runCodex(prompt: String, schemaFileURL: URL) async throws -> AIModelOutput {
        let invocation = ProcessInvocation(
            executable: "/usr/bin/env",
            arguments: [
                "codex", "exec",
                "--ephemeral",
                "--sandbox", "read-only",
                "--output-schema", schemaFileURL.path,
                "-"
            ],
            standardInput: prompt,
            timeoutSeconds: 180
        )
        let result = try await processRunner.run(invocation)
        return try JSONDecoder().decode(AIModelOutput.self, from: Data(result.standardOutput.utf8))
    }
}
