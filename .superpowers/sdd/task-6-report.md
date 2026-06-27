# Task 6 Report: Add Proof-Only Export Readiness Checks

## Implementation Notes
- Added `EchoDeckExportReadiness` to model export gate state explicitly, with proof-oriented messages for missing target media ID, missing accepted cards, and the ready case.
- Added `EchoDeckJSONExporter.readiness(targetMediaID:cards:)` so the readiness logic lives beside the exporter contract and uses the same accepted-card filtering as JSON export.
- Updated `LibraryStore.canExportEchoDeck` to defer to `exportReadiness`, and made `requestEchoExportPanel()` surface the exact readiness message instead of a generic status.
- Added focused tests for both readiness failure modes and the store status message flow.

## Commands Run
- `swift test --filter EchoDeckJSONExporterTests`
- `swift test --filter LibraryStoreTests/testRequestEchoExportPanelUsesReadinessMessage`

## Results
- `EchoDeckJSONExporterTests` passed.
- `LibraryStoreTests/testRequestEchoExportPanelUsesReadinessMessage` passed.

## Files Changed
- `Sources/EchoDeckBuilder/Models/EchoDeckExportSummary.swift`
- `Sources/EchoDeckBuilder/Services/EchoDeckJSONExporter.swift`
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- `Tests/EchoDeckBuilderTests/EchoDeckJSONExporterTests.swift`
- `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`
- `.superpowers/sdd/task-6-report.md`

## Self-Review
- The readiness message now distinguishes the two user-facing blockers the brief called out, which makes the proof harness more explicit without changing the export payload.
- The implementation stays inside the requested file set and keeps the export contract unchanged: JSON export still only includes accepted cards and anchor-only source references.

## Concerns
- None. The focused tests passed and the change remains narrow.
