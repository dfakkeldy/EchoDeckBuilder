# Task 4 Report: Make Non-Local CLI Availability Honest

## Implementation Notes
- Added `LocalCommandAvailability` as a small `Process`-backed seam for checking local command presence.
- `DefaultCardGeneratorResolver` now accepts `LocalCommandAvailability` and uses it to report honest availability for `.claudeCLI` and `.codexCLI`.
- CLI generator resolution now short-circuits to `UnavailableCardGenerator(message: availability.message)` when the command is missing, before constructing `LocalClaudeCLIGenerator` or `LocalCodexCLIGenerator`.
- Added provider tests that cover missing Claude CLI, available Codex CLI, and the resolver short-circuit path for unavailable Claude CLI.

## Commands and Results
- `swift test --filter CardGenerationProviderTests`
- Result: passed, 8 tests, 0 failures

## Files Changed
- `Sources/EchoDeckBuilder/Services/LocalCommandAvailability.swift`
- `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`

## Self-Review
- The resolver change is narrowly scoped and keeps fixture and Foundation Models behavior unchanged.
- The availability seam is easy to override in tests and uses the same message strings that the resolver returns.
- The short-circuit test exercises the unavailable CLI path directly, which helps guard the order of operations.

## Concerns
- `defaultLookup` shells out via `/usr/bin/env which`, so its result still depends on the active process environment and PATH.
- I did not run the full package test suite, only the focused provider filter requested in the task.
