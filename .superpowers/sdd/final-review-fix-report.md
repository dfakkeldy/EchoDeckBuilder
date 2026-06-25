# Final Review Fix Report

## 2026-06-25

- Fixed EPUB archive containment by preflighting `unzip -Z1` entries, rejecting empty, absolute, traversal, repeated-separator, and backslash paths before extraction.
- Added post-extraction validation that rejects symlinks and confirms extracted artifacts remain under the extraction root.
- Added `EPUBPathResolver` for EPUB URI path handling: strips fragments/queries, rejects schemes/hosts, percent-decodes paths, rejects absolute/traversal paths, and resolves against an allowed root.
- Routed container rootfile resolution through the extraction-root resolver and OPF manifest href resolution through the package-root resolver.
- Added scoped cleanup for successful EPUB extraction directories in `LibraryStore.loadImportedBook`.
- Balanced `NSOpenPanel` security-scoped access around the async import task.
- Added a shared app-level Echo JSON export save-panel helper and wired both menu and toolbar export actions to it.
- Added import/generation operation guards: import cancels active generation, import overlap is blocked, generation is blocked during import, and stale generation completions are discarded by token.
- Fixed `CardReviewView` field bindings to read latest card values from `LibraryStore` by card ID.
- Changed `AnkiTSVExporter` to return an empty string when there are no accepted cards.
- Added README language that the MVP generator is deterministic/local and real AI provider selection is out of scope.

Verification run:

- `swift test --filter 'EPUBPathResolverTests|EPUBManifestParserTests|EPUBImportIntegrationTests|LibraryStoreTests|EchoDeckJSONExporterTests|AnkiTSVExporterTests'` passed: 21 tests, 0 failures.
- `swift test` passed: 30 tests, 0 failures.
- `./script/build_and_run.sh --verify` passed.
- `git diff --check` passed.
