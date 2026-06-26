import Foundation

public struct LocalClaudeCLIGenerator: CardGenerator {
    private let processRunner: any ProcessRunning
    private let promptBuilder: AIPromptPackageBuilder
    private let batcher: GenerationBatcher
    private let validator: AIModelOutputValidator

    public init(
        processRunner: any ProcessRunning = LocalProcessRunner(),
        promptBuilder: AIPromptPackageBuilder = AIPromptPackageBuilder(),
        batcher: GenerationBatcher = GenerationBatcher(),
        validator: AIModelOutputValidator = AIModelOutputValidator()
    ) {
        self.processRunner = processRunner
        self.promptBuilder = promptBuilder
        self.batcher = batcher
        self.validator = validator
    }

    public func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        let schema = String(decoding: try promptBuilder.outputSchemaData(), as: UTF8.self)
        let briefOutput = try await runClaude(prompt: promptBuilder.bookBriefPrompt(for: request), schema: schema)
        let briefResult = try validator.validate(briefOutput, batchSections: request.sections)
        let bookBrief = briefResult.bookBrief

        var cards: [DeckCard] = []
        var warnings = briefResult.warnings
        for batch in batcher.batches(from: request.sections, maxSectionsPerBatch: request.settings.batchSize) {
            let prompt = promptBuilder.batchPrompt(for: request, bookBrief: bookBrief, batch: batch)
            let output = try await runClaude(prompt: prompt, schema: schema)
            let result = try validator.validate(output, batchSections: batch)
            cards.append(contentsOf: result.cards)
            warnings.append(contentsOf: result.warnings)
        }

        return CardGenerationResult(bookBrief: bookBrief, cards: cards, warnings: warnings)
    }

    private func runClaude(prompt: String, schema: String) async throws -> AIModelOutput {
        let invocation = ProcessInvocation(
            executable: "/usr/bin/env",
            arguments: ["claude", "-p", "--json-schema", schema],
            standardInput: prompt,
            timeoutSeconds: 180
        )
        let result = try await processRunner.run(invocation)
        return try JSONDecoder().decode(AIModelOutput.self, from: Data(result.standardOutput.utf8))
    }
}
