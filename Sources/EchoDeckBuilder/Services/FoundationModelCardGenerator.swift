import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
public struct FoundationModelCardGenerator: CardGenerator {
    private let maximumSectionCharacters: Int

    public init(maximumSectionCharacters: Int = FoundationModelCardPrompt.maximumSectionCharacters) {
        self.maximumSectionCharacters = maximumSectionCharacters
    }

    public func generateCards(for request: CardGenerationRequest) async throws -> CardGenerationResult {
        let cards = try await generateCards(for: request.sections)

        return CardGenerationResult(
            runMetadata: request.runMetadata,
            bookBrief: BookBrief(
                summary: "Foundation Models generated draft cards from selected source sections.",
                themes: ["on-device generation"],
                keyConcepts: ["source anchors", "local language model"],
                argumentFlow: ["select source sections", "generate draft cards", "review into deck"],
                skipAreas: []
            ),
            cards: cards
        )
    }

    private func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        let availability = FoundationModelAvailability.current()
        guard availability.isAvailable else {
            throw CardGenerationError.unavailable(availability.message)
        }

        var cards: [DeckCard] = []
        cards.reserveCapacity(sections.count)

        for section in sections {
            try Task.checkCancellation()
            if let card = try await generateCard(for: section) {
                cards.append(card)
            }
        }

        return cards
    }

    private func generateCard(for section: BookSection) async throws -> DeckCard? {
        let prompt = FoundationModelCardPrompt.prompt(
            for: section,
            maxCharacters: maximumSectionCharacters
        )

        do {
            return try await requestCard(for: section, prompt: prompt, options: Self.defaultOptions)
        } catch let error as LanguageModelSession.GenerationError {
            return try await recover(from: error, section: section, prompt: prompt)
        }
    }

    private func recover(
        from error: LanguageModelSession.GenerationError,
        section: BookSection,
        prompt: String
    ) async throws -> DeckCard? {
        switch error {
        case .exceededContextWindowSize:
            let shorterPrompt = FoundationModelCardPrompt.prompt(
                for: section,
                maxCharacters: retryMaximumSectionCharacters
            )
            return try await requestCardOrMapFailure(for: section, prompt: shorterPrompt, options: Self.retryOptions)
        case .decodingFailure:
            return try await requestCardOrMapFailure(for: section, prompt: prompt, options: Self.retryOptions)
        case .guardrailViolation, .refusal:
            return nil
        case .unsupportedLanguageOrLocale, .assetsUnavailable, .unsupportedGuide, .rateLimited, .concurrentRequests:
            throw Self.cardGenerationError(from: error)
        @unknown default:
            throw CardGenerationError.failed("Foundation Models generation failed")
        }
    }

    private func requestCardOrMapFailure(
        for section: BookSection,
        prompt: String,
        options: GenerationOptions
    ) async throws -> DeckCard? {
        do {
            return try await requestCard(for: section, prompt: prompt, options: options)
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.cardGenerationError(from: error)
        }
    }

    private func requestCard(
        for section: BookSection,
        prompt: String,
        options: GenerationOptions
    ) async throws -> DeckCard? {
        let session = LanguageModelSession(instructions: FoundationModelCardPrompt.instructions)
        let response = try await session.respond(
            to: prompt,
            generating: FoundationModelGeneratedCardDraft.self,
            options: options
        )
        return GeneratedCardDraftMapper.deckCard(from: response.content.cardDraft, section: section)
    }

    private static var defaultOptions: GenerationOptions {
        GenerationOptions(sampling: .greedy, temperature: 0.2, maximumResponseTokens: 320)
    }

    private static var retryOptions: GenerationOptions {
        GenerationOptions(sampling: .greedy, temperature: 0.0, maximumResponseTokens: 260)
    }

    private var retryMaximumSectionCharacters: Int {
        guard maximumSectionCharacters > 1 else {
            return maximumSectionCharacters
        }

        return min(maximumSectionCharacters - 1, max(500, maximumSectionCharacters / 2))
    }

    private static func cardGenerationError(from error: LanguageModelSession.GenerationError) -> CardGenerationError {
        switch error {
        case .exceededContextWindowSize:
            return .failed("A source section is too large for Foundation Models")
        case .assetsUnavailable:
            return .unavailable(FoundationModelAvailability.modelAssetsUnavailableMessage)
        case .guardrailViolation, .refusal:
            return .failed("Foundation Models blocked the generated card for this section")
        case .unsupportedGuide:
            return .failed("The Foundation Models card schema is not supported")
        case .unsupportedLanguageOrLocale:
            return .unavailable(FoundationModelAvailability.unsupportedLanguageMessage)
        case .decodingFailure:
            return .failed("Foundation Models could not produce a valid card draft")
        case .rateLimited:
            return .failed("Foundation Models is rate limited. Try again shortly.")
        case .concurrentRequests:
            return .failed("Foundation Models is already generating a response")
        @unknown default:
            return .failed("Foundation Models generation failed")
        }
    }
}

@available(macOS 26.0, *)
@Generable
private struct FoundationModelGeneratedCardDraft {
    @Guide(description: "The front of a flashcard. Use a question for basic cards or a cloze sentence for cloze cards.")
    var frontText: String

    @Guide(description: "The answer or explanation. Keep this short and grounded in the supplied section.")
    var backText: String

    @Guide(description: "Card kind", .anyOf(["basic", "cloze"]))
    var kind: String

    @Guide(description: "Short topical tags", .maximumCount(4))
    var tags: [String]

    var cardDraft: GeneratedCardDraft {
        GeneratedCardDraft(
            frontText: frontText,
            backText: backText,
            kind: CardKind(rawValue: kind) ?? .basic,
            tags: tags
        )
    }
}
#endif
