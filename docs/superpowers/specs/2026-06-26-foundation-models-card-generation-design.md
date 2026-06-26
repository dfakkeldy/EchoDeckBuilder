# Foundation Models Card Generation Design

## Context

EchoDeckBuilder is a SwiftPM macOS app that imports private EPUBs, extracts source-anchored sections, generates draft study cards, lets the user review them, and exports Echo deck JSON vNext plus Anki TSV. The app currently targets macOS 14 in `Package.swift`, uses Swift 6, and injects card generation through the async `CardGenerator` protocol. The active generator is `FixtureCardGenerator`, which is deterministic, local, and test-friendly.

The Swift AI Playbook and Xcode's bundled Foundation Models guide both point toward the same fit: Foundation Models is well suited for summarization, extraction, classification, structured generation, and paraphrasing when the app supplies the source text. It is not the right source of world knowledge, fresh facts, broad reasoning, or deterministic export/anchor behavior.

Foundation Models is macOS 26+ and Apple Intelligence-gated. The app should preserve its current macOS 14 support and add Foundation Models as an optional, availability-gated provider.

## Goals

- Add a real local AI card generator that can create reviewable basic and cloze cards from imported EPUB sections.
- Keep EPUB content on device when using the Foundation Models provider.
- Preserve deterministic source anchors. The model generates card content only; `BookSection.anchor` remains the exported `sourceAnchor`.
- Preserve the existing fixture generator as the default fallback and as the unit-test baseline.
- Make provider availability explicit in the UI so unsupported Macs, disabled Apple Intelligence, unavailable model assets, and unsupported languages degrade gracefully.
- Keep generated cards paraphrased and short, avoiding long quotations from copyrighted source material.

## Non-Goals

- Do not raise the package platform floor above macOS 14 for this phase.
- Do not add cloud AI providers.
- Do not train or ship Foundation Models custom adapters.
- Do not add Create ML, Vision, OCR, or text-to-speech features.
- Do not let the model create, rewrite, or validate Echo source anchors.
- Do not replace the review workflow; generated cards remain drafts until accepted.
- Do not implement APKG sidecar generation in this phase.

## Architecture

The implementation should add a second `CardGenerator` implementation next to `FixtureCardGenerator`:

- `FixtureCardGenerator`: deterministic local fallback, available on all supported macOS versions.
- `FoundationModelCardGenerator`: on-device AI provider, compiled only when Foundation Models is importable and run only on macOS 26+ with an available system model.

`LibraryStore` should continue to depend on `any CardGenerator`, but the app should gain a small provider-selection layer so the active generator can switch between fixture and Foundation Models. This layer should keep UI and availability concerns out of the generator itself where practical.

Suggested units:

- `CardGenerationProvider`: enum for fixture vs Foundation Models.
- `CardGenerationAvailability`: small value type that explains whether the selected provider can run and what user-facing status to show.
- `FoundationModelCardGenerator`: converts `[BookSection]` into `[DeckCard]`.
- `GeneratedCardDraft`: `@Generable` output type used only by the Foundation Models provider.
- `FoundationModelCardPrompt`: helper that builds concise instructions and per-section prompts without mixing developer instructions and source text.

The existing export services should not change except for tests proving AI-generated cards still export with the same accepted-card and anchor-only rules.

## Generation Flow

1. User imports an EPUB.
2. `LibraryStore` stores extracted `[BookSection]` as it does today.
3. User chooses a generator provider in the inspector.
4. User taps Generate Cards.
5. `LibraryStore` asks the active `CardGenerator` to generate cards for the current sections.
6. For Foundation Models, the generator processes sections in bounded batches or per-section sessions.
7. Each generated draft maps to a `DeckCard` with:
   - `sectionID` from the source section.
   - `sourceAnchor` from the source section.
   - `reviewState` set to `.draft`.
   - `tags` including `"generated"` and `"foundation-models"`.
8. The user reviews, edits, accepts, or rejects cards exactly as today.
9. Existing exporters include only accepted cards.

Per-section generation is the first implementation choice. It avoids the whole-book context-window problem, keeps failures localized, and naturally preserves one or more cards per anchor. If a section is too long, the generator should use a bounded excerpt from that section rather than sending the entire EPUB spine item.

## Foundation Models Use

Use `LanguageModelSession` with concise developer instructions:

- Generate study cards from only the supplied EPUB section.
- Prefer one high-signal card per section for the first phase.
- Use mixed basic and cloze cards only when the source supports them.
- Paraphrase. Do not copy long source passages.
- Avoid making claims that are not present in the section.
- Return empty or skipped output when the section lacks enough substance.

Use `@Generable` structured output instead of asking for JSON. A good first schema is:

```swift
@Generable
struct GeneratedCardDraft {
    @Guide(description: "The front of a flashcard. Use a question for basic cards or a cloze sentence for cloze cards.")
    var frontText: String

    @Guide(description: "The answer or explanation. Keep this short and grounded in the supplied section.")
    var backText: String

    @Guide(description: "Card kind", .anyOf(["basic", "cloze"]))
    var kind: String

    @Guide(description: "Short topical tags", .maximumCount(4))
    var tags: [String]
}
```

The implementation plan must verify the exact `@Guide` attribute names against Xcode 26.5 before writing the generator, then prove the chosen schema with `swift build`. The design intent is constrained structured generation, not manual JSON parsing.

The first implementation should avoid Foundation Models tools. The source text is already known locally, and tools add context-window cost. Add tool calling later only if card generation needs access to app-side retrieval, glossary lookup, or dedupe services.

The first implementation should not use dynamic schemas. Dynamic generation is useful if users can define arbitrary card fields or exact variable card counts at runtime, but `DeckCard` has a stable shape. `@Generable` is safer and easier to test.

## Availability And Fallback

Foundation Models entry points must be guarded in three layers:

- Compile-time: `#if canImport(FoundationModels)`.
- Runtime OS: `@available(macOS 26.0, *)`.
- Model availability: `SystemLanguageModel.default.availability`.

The UI should show a clear status for these cases:

- Current OS does not support Foundation Models.
- Device is not eligible for Apple Intelligence.
- Apple Intelligence is not enabled.
- The model is not ready.
- The current language is unsupported.
- Foundation Models is available.

When unavailable, the app should keep the fixture generator usable. The Generate Cards button should either use the selected available provider or explain why the selected provider cannot run. It should not crash or construct a `LanguageModelSession` before availability passes.

## Error Handling

The Foundation Models provider should convert model failures into a domain error that `LibraryStore` can display in `statusMessage`.

Handle at least:

- `exceededContextWindowSize`: retry with a shorter section excerpt once, then fail that section with a useful message.
- `guardrailViolation` or refusal: skip the section and continue when possible, or fail with a neutral message if every section is blocked.
- `unsupportedLanguageOrLocale`: stop and show that the current language is unsupported.
- `assetsUnavailable` or model-not-ready cases: report that Apple Intelligence assets are unavailable.
- `decodingFailure`: retry once with the same section and lower creativity; if still failing, skip that section.
- `rateLimited` or concurrent requests: serialize requests per session and surface retry guidance if rate limited.
- Task cancellation: preserve the existing cancellation behavior in `LibraryStore`.

Partial generation should not replace existing reviewed cards unless the run finishes for the active generation token. This preserves the current stale-generation protection.

## UI Changes

The inspector should get a compact generation section:

- Provider picker: Fixture, Foundation Models.
- Availability/status text for the selected provider.
- Optional card profile controls only if they are needed for this phase. The first implementation can keep the current "balanced mixed" behavior from the README without adding new controls.

The toolbar Generate Cards action should remain the primary command. The card review UI should not need structural changes for this phase.

Generated AI content should be visibly understandable as draft content through the existing review state. If a future UI shows cards outside review, add explicit AI-generated labeling.

## Testing

Unit tests should not require Apple Intelligence. Keep most tests provider-independent by introducing small seams:

- Prompt builder tests verify source text, heading, anchor, and constraints are included correctly.
- Mapping tests verify `GeneratedCardDraft` values become `DeckCard` values with source anchors copied from `BookSection`.
- Availability tests verify unavailable states choose the fixture fallback or disable Foundation Models with the right status.
- Store tests verify provider selection preserves overlapping-generation prevention and stale-generation invalidation.
- Export tests verify AI-generated accepted cards still export anchor-only Echo JSON.

Manual testing on a macOS 26+ Apple Intelligence-capable Mac should cover:

- Foundation Models available happy path.
- Apple Intelligence disabled.
- Model not ready.
- Unsupported or unavailable provider on macOS below 26.
- Long section truncation.
- Guardrail/refusal handling.
- Generated cards are paraphrased and anchored correctly.

Run `swift test` after implementation. If a macOS 26 Apple Intelligence environment is available, also run the app manually with a small EPUB and inspect generated cards before export.

## Rollout

Implement in small steps:

1. Add provider and availability models with tests.
2. Add prompt/schema mapping tests and pure mapping code.
3. Add the Foundation Models generator behind compile-time and runtime gates.
4. Wire provider selection into `LibraryStore`.
5. Add inspector UI for provider and availability status.
6. Run unit tests and perform manual availability checks.

The feature should ship as optional. Users who cannot run Foundation Models should still be able to import EPUBs, generate fixture cards, review cards, and export decks.

## Risks

- Foundation Models may generate plausible but weak cards. Mitigation: keep every card as a draft and make review/edit the default workflow.
- Context limits may reject long sections. Mitigation: per-section sessions and bounded excerpts.
- Guardrails may block benign source text. Mitigation: neutral error messages, skip blocked sections when possible, preserve fixture fallback.
- Availability varies by OS, hardware, settings, region, language, and model readiness. Mitigation: explicit availability UI and no session creation until checks pass.
- SDK API details can shift. Mitigation: use Xcode 26.5 bundled documentation during implementation and keep all Foundation Models code isolated.
