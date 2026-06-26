# Task 3 Report: Foundation Models Availability And Generator

## What I implemented

- Added `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`.
  - Bridges compile-time and runtime availability behind `#if canImport(FoundationModels)` and `@available(macOS 26.0, *)`.
  - Maps `SystemLanguageModel.default.availability` and locale support into `CardGenerationAvailability`.
- Added `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`.
  - Introduces the real Foundation Models-backed `CardGenerator` on macOS 26+.
  - Uses `FoundationModelCardPrompt` for prompt construction and `GeneratedCardDraftMapper` for deterministic anchor-preserving mapping.
  - Handles retry/fallback behavior for `exceededContextWindowSize` and `decodingFailure`.
  - Maps `LanguageModelSession.GenerationError` into existing `CardGenerationError` messages.
  - Keeps `FoundationModels` imports and generated schema fully compile-gated.
- Updated `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`.
  - `DefaultCardGeneratorResolver.availability(for: .foundationModels)` now uses `FoundationModelAvailability.current()`.
  - `generator(for: .foundationModels)` now returns `FoundationModelCardGenerator()` only when compile-time and runtime gates both pass, otherwise preserves the unavailable fallback.
- Updated `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`.
  - Added `testDefaultResolverKeepsFixtureAvailable()` to lock down fixture fallback availability and empty generation behavior.

## Tests and typechecks run

### Foundation Models SDK typechecks

1. Command:
   ```bash
   cat >/tmp/fm_schema_check.swift <<'SWIFT'
   #if canImport(FoundationModels)
   import FoundationModels

   @available(macOS 26.0, *)
   @Generable
   struct GeneratedCardDraftCheck {
       @Guide(description: "The front of a flashcard. Use a question for basic cards or a cloze sentence for cloze cards.")
       var frontText: String

       @Guide(description: "The answer or explanation. Keep this short and grounded in the supplied section.")
       var backText: String

       @Guide(description: "Card kind", .anyOf(["basic", "cloze"]))
       var kind: String

       @Guide(description: "Short topical tags", .maximumCount(4))
       var tags: [String]
   }

   @available(macOS 26.0, *)
   func check() async throws {
       let session = LanguageModelSession(instructions: "Generate cards.")
       let response = try await session.respond(
           to: "Create a card.",
           generating: GeneratedCardDraftCheck.self,
           options: GenerationOptions(sampling: .greedy, temperature: 0.2, maximumResponseTokens: 300)
       )
       _ = response.content.frontText
   }
   #endif
   SWIFT
   swiftc -target arm64-apple-macosx14.0 -typecheck /tmp/fm_schema_check.swift
   ```
   Result: passed with exit code 0 and no diagnostics.

2. Additional API validation because the brief sample used `supportsLocale()` while the verified assumptions referenced `supportsLocale(_:)`.
   Commands:
   ```bash
   cat >/tmp/fm_locale_check.swift <<'SWIFT'
   #if canImport(FoundationModels)
   import Foundation
   import FoundationModels

   @available(macOS 26.0, *)
   func check(model: SystemLanguageModel = .default) {
       _ = model.supportsLocale(Locale.current)
   }
   #endif
   SWIFT
   swiftc -target arm64-apple-macosx14.0 -typecheck /tmp/fm_locale_check.swift
   ```
   ```bash
   cat >/tmp/fm_locale_zeroarg_check.swift <<'SWIFT'
   #if canImport(FoundationModels)
   import FoundationModels

   @available(macOS 26.0, *)
   func check(model: SystemLanguageModel = .default) {
       _ = model.supportsLocale()
   }
   #endif
   SWIFT
   swiftc -target arm64-apple-macosx14.0 -typecheck /tmp/fm_locale_zeroarg_check.swift
   ```
   Result: both signatures typechecked successfully with exit code 0 and no diagnostics.

3. Additional error-switch validation for the briefed `GenerationError` pattern matching.
   Command:
   ```bash
   cat >/tmp/fm_error_switch_check.swift <<'SWIFT'
   #if canImport(FoundationModels)
   import FoundationModels

   @available(macOS 26.0, *)
   func check(error: LanguageModelSession.GenerationError) {
       switch error {
       case .exceededContextWindowSize:
           break
       case .decodingFailure:
           break
       case .guardrailViolation, .refusal:
           break
       case .unsupportedLanguageOrLocale, .assetsUnavailable, .unsupportedGuide, .rateLimited, .concurrentRequests:
           break
       @unknown default:
           break
       }
   }
   #endif
   SWIFT
   swiftc -target arm64-apple-macosx14.0 -typecheck /tmp/fm_error_switch_check.swift
   ```
   Result: passed with exit code 0 and no diagnostics.

### SwiftPM build and tests

1. Focused guard test before implementation:
   ```bash
   swift test --filter CardGenerationProviderTests/testDefaultResolverKeepsFixtureAvailable
   ```
   Result: passed.
   Key output:
   ```text
   Test Case '-[EchoDeckBuilderTests.CardGenerationProviderTests testDefaultResolverKeepsFixtureAvailable]' passed
   ```

2. Package build after implementation:
   ```bash
   swift build
   ```
   Result: passed.
   Key output:
   ```text
   Build complete!
   ```

3. Focused provider test suite after implementation:
   ```bash
   swift test --filter CardGenerationProviderTests
   ```
   Result: passed.
   Key output:
   ```text
   Executed 4 tests, with 0 failures (0 unexpected)
   ```

4. Full package test suite before commit:
   ```bash
   swift test
   ```
   Result: passed.
   Key output:
   ```text
   Executed 49 tests, with 0 failures (0 unexpected)
   ```

## TDD evidence

- Test-first step performed: `testDefaultResolverKeepsFixtureAvailable()` was added before the Foundation Models implementation edits.
- RED was not practical for this specific guard test because the brief explicitly expected it to pass before and after the resolver changes; its purpose was to preserve the fixture fallback contract during Task 3.

### Pre-implementation command/output

Command:
```bash
swift test --filter CardGenerationProviderTests/testDefaultResolverKeepsFixtureAvailable
```

Output:
```text
Test Case '-[EchoDeckBuilderTests.CardGenerationProviderTests testDefaultResolverKeepsFixtureAvailable]' passed
```

### Post-implementation GREEN command/output

Command:
```bash
swift test --filter CardGenerationProviderTests
```

Output:
```text
Test Suite 'CardGenerationProviderTests' passed
Executed 4 tests, with 0 failures (0 unexpected)
```

## Files changed

- `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`
- `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`
- `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`

## Commit

- `557dc5e feat: add foundation models card generator`

## Self-review findings

- Compile-time and runtime gates are both in place, so macOS 14 continues to build and use the fixture fallback path.
- The Foundation Models generator only produces draft content and tags; anchors still come from deterministic app logic through `GeneratedCardDraftMapper`.
- Error mapping stays narrow and user-facing, matching the briefed messages.
- No unrelated files or architecture were touched.

## Issues or concerns

- No runtime generation was exercised on a macOS 26 Apple Intelligence-capable machine in this environment; validation here is compile-time plus package test coverage.

## Task 3 review-fix follow-up

### Fix summary

- Made the availability-layer `.modelNotReady` message explicit about Apple Intelligence language model assets downloading or not being ready, without inventing a preflight `assetsUnavailable` availability case.
- Shared app-owned Foundation Models messaging constants so generation-time `.assetsUnavailable` still reports the concrete user-facing asset-unavailable message.
- Added deterministic mapper-side length guards in `GeneratedCardDraftMapper` so overlong model output is rejected before it becomes a draft `DeckCard`, while preserving deterministic anchor assignment in app code.
- Added focused tests for overlong front/back rejection and for the shared asset-state messages.

### Tests/typechecks run and results

- `swift test --filter GeneratedCardDraftTests`
  - Passed: `Executed 5 tests, with 0 failures (0 unexpected)`
- `swift test --filter CardGenerationProviderTests`
  - Passed: `Executed 5 tests, with 0 failures (0 unexpected)`
- `swift test`
  - Passed: `Executed 52 tests, with 0 failures (0 unexpected)`
- `swift build`
  - Passed: `Build complete!`

### Files changed

- `Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`
- `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`
- `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`
- `Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`
- `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`
- `.superpowers/sdd/task-3-report.md`

### Self-review findings/concerns

- The new output guard sits exactly at the generated-draft-to-`DeckCard` mapping boundary, so model output can be rejected deterministically without changing anchor ownership.
- Availability messaging is now more honest about the macOS 26 asset-preparation state, and generation-time asset failures keep their distinct concrete message.
- The guard currently rejects oversize output rather than truncating it, which matches the review ask and avoids silently changing model text.
- Runtime Foundation Models behavior still is not exercised in this environment; verification here is build/test coverage plus SDK-gated code inspection.
