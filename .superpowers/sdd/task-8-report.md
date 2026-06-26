Status: completed

Summary:
- Added diagnostics coverage for visual prompt metadata and prompt count in `DiagnosticsExporter`.
- Updated `EchoDeckJSONExporterTests` to verify accepted cards with visual metadata do not leak visual fields in JSON output.
- Updated `AnkiTSVExporterTests` to verify accepted cards with visual metadata do not leak visual prompt data in TSV output.

Verification:
- `swift test --filter EchoDeckJSONExporterTests` — passed (3 tests).
- `swift test --filter AnkiTSVExporterTests` — passed (3 tests).
- `swift test --filter DiagnosticsExporterTests` — passed (2 tests).
- `swift test` — passed (65 tests).
- `swift build` — passed.
- `./script/build_and_run.sh --verify` — passed.

Commit SHA:
- f2bcff6

Concerns:
- None.
