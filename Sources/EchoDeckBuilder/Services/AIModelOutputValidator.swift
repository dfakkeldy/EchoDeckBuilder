import Foundation

public enum AIModelOutputValidationError: Error, Equatable, LocalizedError, Sendable {
    case emptyBookBrief
    case malformedSourceAnchor(String)
    case sourceAnchorOutsideBatch(String)
    case emptyFrontText(String)
    case emptyBackText(String)
    case unsupportedCardKind(String, String)
    case invalidClozeText(String)
    case invalidVisual(String)
    case longSourceQuotation(String)

    public var errorDescription: String? {
        switch self {
        case .emptyBookBrief:
            "The AI response did not include a book brief."
        case .malformedSourceAnchor(let anchor):
            "The AI response included a malformed source anchor: \(anchor)"
        case .sourceAnchorOutsideBatch(let anchor):
            "The AI response referenced an anchor outside the current batch: \(anchor)"
        case .emptyFrontText(let anchor):
            "The AI response included an empty front text for \(anchor)."
        case .emptyBackText(let anchor):
            "The AI response included an empty back text for \(anchor)."
        case .unsupportedCardKind(let kind, let anchor):
            "The AI response used unsupported card kind \(kind) for \(anchor)."
        case .invalidClozeText(let anchor):
            "The AI response included an invalid cloze card for \(anchor)."
        case .invalidVisual(let anchor):
            "The AI response included invalid visual metadata for \(anchor)."
        case .longSourceQuotation(let anchor):
            "The AI response copied too much source text for \(anchor)."
        }
    }
}

public struct AIModelOutputValidator: Sendable {
    public init() {}

    public func validate(_ output: AIModelOutput, batchSections: [BookSection]) throws -> CardGenerationResult {
        let summary = output.bookBrief.summary.trimmedForGeneration
        guard !summary.isEmpty else {
            throw AIModelOutputValidationError.emptyBookBrief
        }

        let sectionByAnchor = Dictionary(uniqueKeysWithValues: batchSections.map { ($0.anchor.suffix, $0) })
        let cards = try output.cards.map { rawCard -> DeckCard in
            let anchorText = rawCard.sourceAnchor.trimmedForGeneration
            guard let anchor = SourceAnchor(suffix: anchorText) else {
                throw AIModelOutputValidationError.malformedSourceAnchor(anchorText)
            }
            guard let section = sectionByAnchor[anchor.suffix] else {
                throw AIModelOutputValidationError.sourceAnchorOutsideBatch(anchor.suffix)
            }

            let frontText = rawCard.frontText.trimmedForGeneration
            let backText = rawCard.backText.trimmedForGeneration
            guard !frontText.isEmpty else {
                throw AIModelOutputValidationError.emptyFrontText(anchor.suffix)
            }
            guard !backText.isEmpty else {
                throw AIModelOutputValidationError.emptyBackText(anchor.suffix)
            }

            let kind = try cardKind(from: rawCard.kind, anchor: anchor.suffix)
            let clozeText = rawCard.clozeText?.trimmedForGeneration ?? ""
            if kind == .cloze {
                guard clozeText.contains("{{c1::") else {
                    throw AIModelOutputValidationError.invalidClozeText(anchor.suffix)
                }
            }
            try rejectLongSourceQuotation(
                texts: [frontText, backText, clozeText],
                sourceText: section.text,
                anchor: anchor.suffix
            )

            return DeckCard(
                sectionID: section.id,
                frontText: frontText,
                backText: backText,
                kind: kind,
                tags: rawCard.tags.map(\.trimmedForGeneration).filter { !$0.isEmpty },
                sourceAnchor: anchor,
                visual: try visual(from: rawCard.visual, anchor: anchor.suffix),
                clozeText: clozeText.isEmpty ? nil : clozeText,
                aiMetadata: CardAIMetadata(
                    importance: rawCard.importance,
                    confidence: rawCard.confidence,
                    rationale: rawCard.rationale.trimmedForGeneration
                )
            )
        }

        return CardGenerationResult(
            runMetadata: GenerationRunMetadata(
                provider: output.run.provider.trimmedForGeneration,
                model: output.run.model.trimmedForGeneration,
                sourceScope: output.run.sourceScope.trimmedForGeneration,
                imageMode: output.run.imageMode.trimmedForGeneration
            ),
            bookBrief: BookBrief(
                summary: summary,
                themes: output.bookBrief.themes.cleanedGenerationStrings,
                keyConcepts: output.bookBrief.keyConcepts.cleanedGenerationStrings,
                argumentFlow: output.bookBrief.argumentFlow.cleanedGenerationStrings,
                skipAreas: output.bookBrief.skipAreas.cleanedGenerationStrings
            ),
            cards: cards,
            warnings: output.warnings.cleanedGenerationStrings.map(GenerationWarning.init(message:))
        )
    }

    private func cardKind(from rawValue: String, anchor: String) throws -> CardKind {
        guard let kind = CardKind(rawValue: rawValue.trimmedForGeneration) else {
            throw AIModelOutputValidationError.unsupportedCardKind(rawValue, anchor)
        }
        return kind
    }

    private func visual(from rawVisual: AIModelOutput.Visual?, anchor: String) throws -> CardVisual? {
        guard let rawVisual else {
            return nil
        }
        let prompt = rawVisual.imagePrompt.trimmedForGeneration
        let altText = rawVisual.altText.trimmedForGeneration
        guard !prompt.isEmpty, !altText.isEmpty else {
            throw AIModelOutputValidationError.invalidVisual(anchor)
        }
        return CardVisual(
            priority: CardVisualPriority(rawValue: rawVisual.priority.trimmedForGeneration) ?? .medium,
            imagePrompt: prompt,
            altText: altText
        )
    }

    private func rejectLongSourceQuotation(texts: [String], sourceText: String, anchor: String) throws {
        let sourceWords = sourceText.normalizedQuoteWords
        guard sourceWords.count >= 14 else {
            return
        }

        let candidateTexts = texts.map(\.normalizedForQuoteDetection)
        for startIndex in 0...(sourceWords.count - 14) {
            let phrase = sourceWords[startIndex..<(startIndex + 14)].joined(separator: " ")
            guard phrase.count >= 80 else {
                continue
            }
            if candidateTexts.contains(where: { $0.contains(phrase) }) {
                throw AIModelOutputValidationError.longSourceQuotation(anchor)
            }
        }
    }
}

private extension String {
    var trimmedForGeneration: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedForQuoteDetection: String {
        lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    var normalizedQuoteWords: [String] {
        normalizedForQuoteDetection
            .split(separator: " ")
            .map(String.init)
    }
}

private extension Array where Element == String {
    var cleanedGenerationStrings: [String] {
        map(\.trimmedForGeneration).filter { !$0.isEmpty }
    }
}
