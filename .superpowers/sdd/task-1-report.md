# Task 1 Report: Provider Selection And Resolver Skeleton

## What I implemented or attempted

Implemented the Task 1 provider-selection and resolver skeleton exactly within the requested module surface:

- Added `CardGenerationProvider` with stable `fixture` and `foundationModels` cases plus display names.
- Added `CardGenerationAvailability` with `available`/`unavailable` factories.
- Added `CardGenerationError`.
- Added resolver abstractions and defaults:
  - `CardGeneratorResolving`
  - `DefaultCardGeneratorResolver`
  - `FixedCardGeneratorResolver`
  - `UnavailableCardGenerator`
- Updated `LibraryStore` to:
  - track `selectedGenerationProvider`
  - expose `generationAvailability`
  - gate `canGenerateCards` on resolver availability
  - support resolver injection while preserving the existing fixture-generator initializer path
  - select the active generator via resolver during generation
- Updated `EchoDeckBuilderApp` to initialize `LibraryStore` with `DefaultCardGeneratorResolver()`.
- Added the new provider/resolver tests and appended the requested `LibraryStore` tests and helper resolvers.

## Tests run and results

All requested focused tests and the full package suite passed.

1. `swift test --filter CardGenerationProviderTests`
   - RED: failed as expected before implementation
   - GREEN: passed, 3 tests, 0 failures
2. `swift test --filter LibraryStoreTests/testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability`
   - RED: failed as expected before implementation
   - GREEN: passed, 1 test, 0 failures
3. `swift test --filter LibraryStoreTests`
   - Passed, 11 tests, 0 failures
4. `swift test`
   - Passed, 39 tests, 0 failures

## TDD Evidence

### RED

Command:

```bash
swift test --filter CardGenerationProviderTests
```

Output excerpt:

```text
error: cannot find 'CardGenerationProvider' in scope
error: cannot find 'CardGenerationAvailability' in scope
error: cannot find 'FixedCardGeneratorResolver' in scope
```

Command:

```bash
swift test --filter LibraryStoreTests/testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability
```

Output excerpt:

```text
error: cannot find type 'CardGeneratorResolving' in scope
error: extra arguments at positions #2, #3 in call
note: 'init(sections:cards:generator:)' declared here
```

### GREEN

Command:

```bash
swift test --filter CardGenerationProviderTests
```

Output excerpt:

```text
Test Suite 'CardGenerationProviderTests' passed
Executed 3 tests, with 0 failures
```

Command:

```bash
swift test --filter LibraryStoreTests/testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability
```

Output excerpt:

```text
Test Suite 'LibraryStoreTests' passed
Executed 1 test, with 0 failures
```

Command:

```bash
swift test --filter LibraryStoreTests
```

Output excerpt:

```text
Executed 11 tests, with 0 failures
```

Command:

```bash
swift test
```

Output excerpt:

```text
Executed 39 tests, with 0 failures
```

## Files changed

- `Sources/EchoDeckBuilder/Services/CardGenerationProvider.swift`
- `Sources/EchoDeckBuilder/Services/CardGenerationAvailability.swift`
- `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`
- `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`
- `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`
- `.superpowers/sdd/task-1-report.md`

## Self-review findings

- Verified the legacy fixture path still exists through `LibraryStore(sections:cards:generator:)`, now bridged through `FixedCardGeneratorResolver`.
- Kept the new availability messaging and resolver behavior exactly aligned with the task brief.
- Confirmed unavailable provider selection blocks generation immediately and reports the resolver message without starting async work.
- Confirmed provider-based generation requests the selected provider and still updates cards/status as before.

## Any issues or concerns

No blocking issues. The default resolver intentionally leaves Foundation Models unavailable with the exact placeholder message from the brief until later tasks connect a real implementation.

---

## Fix Summary (Task-review follow-up)

- Added provider allowlisting to `FixedCardGeneratorResolver` while preserving the existing default `init(generator:)` behavior that marks both `.fixture` and `.foundationModels` available.
- Updated the legacy `LibraryStore(sections:cards:generator:)` initializer to use a fixture-only fixed resolver so later mutation of `selectedGenerationProvider` cannot silently treat Foundation Models as ready.
- Added a focused `LibraryStore` regression test proving the legacy initializer reports Foundation Models as unavailable, refuses generation, and never calls the injected fixture generator after provider mutation.

## Tests Run And Results

1. `swift test --filter CardGenerationProviderTests`
   - Passed, 3 tests, 0 failures
2. `swift test --filter LibraryStoreTests`
   - Passed, 12 tests, 0 failures
3. `swift test`
   - Passed, 40 tests, 0 failures

## Files Changed

- `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`
- `.superpowers/sdd/task-1-report.md`

## Self-review Findings/Concerns

- The compatibility fix stays narrowly scoped to the legacy initializer path and does not alter the plan-mandated behavior of `FixedCardGeneratorResolver(generator:)`.
- The unavailable message for the limited resolver matches the default resolver's current Foundation Models placeholder, which keeps degradation behavior consistent.
- No additional concerns after the required focused and full test runs.
