import Foundation

public struct LocalClaudeCLIGenerator: CardGenerator {
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
        let schema = String(decoding: try promptBuilder.outputSchemaData(), as: UTF8.self)
        let workingDirectory = try makeWorkingDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let briefOutput = try await runClaude(
            prompt: promptBuilder.bookBriefPrompt(for: request),
            schema: schema,
            settings: request.settings,
            workingDirectory: workingDirectory
        )
        let briefResult = try validator.validate(briefOutput, batchSections: request.sections)
        let bookBrief = briefResult.bookBrief

        var cards: [DeckCard] = []
        var warnings = briefResult.warnings
        for batch in batcher.batches(from: request.sections, maxSectionsPerBatch: request.settings.batchSize) {
            let prompt = promptBuilder.batchPrompt(for: request, bookBrief: bookBrief, batch: batch)
            let output = try await runClaude(
                prompt: prompt,
                schema: schema,
                settings: request.settings,
                workingDirectory: workingDirectory
            )
            let result = try validator.validate(output, batchSections: batch)
            cards.append(contentsOf: result.cards)
            warnings.append(contentsOf: result.warnings)
        }

        return CardGenerationResult(
            runMetadata: briefResult.runMetadata,
            bookBrief: bookBrief,
            cards: cards,
            warnings: warnings
        )
    }

    private func makeWorkingDirectory() throws -> URL {
        let directory = temporaryDirectory
            .appending(path: "EchoDeckBuilder-ClaudeCLI-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func runClaude(
        prompt: String,
        schema: String,
        settings: GenerationSettings,
        workingDirectory: URL
    ) async throws -> AIModelOutput {
        var arguments = [
            "claude",
            "-p",
            "--safe-mode",
            "--tools", "",
            "--disable-slash-commands",
            "--strict-mcp-config",
            "--mcp-config", "{}",
            "--no-session-persistence",
            "--permission-mode", "dontAsk",
            "--input-format", "text",
            "--json-schema", schema
        ]
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty, model != "default" {
            arguments.append(contentsOf: ["--model", model])
        }
        arguments.append("Read the EchoDeckBuilder generation request from stdin and return only JSON matching the schema.")

        let invocation = ProcessInvocation(
            executable: "/usr/bin/env",
            arguments: arguments,
            standardInput: prompt,
            workingDirectory: workingDirectory,
            timeoutSeconds: 180
        )
        let result = try await processRunner.run(invocation)
        return try JSONDecoder().decode(AIModelOutput.self, from: Data(result.standardOutput.utf8))
    }
}
