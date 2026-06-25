# Final Re-review Fix Report

Date: 2026-06-25

## Findings Fixed

1. `EPUBArchiveExtractor` no longer pipes `unzip -Z1` output through unread stdout/stderr handles. Listing output and stderr are redirected to temporary files before `waitUntilExit`, avoiding pipe backpressure deadlocks on large EPUBs.
2. `FixtureCardGenerator` no longer includes section headings in generated card fronts. Fronts use section/block anchors, and a long-heading regression test verifies the heading is not copied verbatim.
3. `EPUBPathResolver` now allows EPUB-internal dot segments for referenced paths, strips query/fragment data, percent-decodes path components, normalizes relative paths, and validates containment under the extracted EPUB root. Archive entry validation remains strict.
4. `LibraryStore` trims `targetMediaID` when enabling Echo JSON export and when exporting data, so whitespace-only IDs do not enable export and exported IDs are normalized.

## Tests Added or Updated

- Long heading is not copied into generated card front text.
- Manifest href with `../` that normalizes inside the extracted EPUB root is accepted.
- Manifest href traversal outside the extracted EPUB root is rejected.
- Whitespace-only target media ID does not allow export, and exported Echo JSON uses a trimmed target media ID.
- Path resolver tests now cover dot-segment normalization and containment separately from strict archive-entry validation.

## Verification

- `swift test --filter EPUBPathResolverTests`: passed
- `swift test --filter EPUBManifestParserTests`: passed
- `swift test --filter FixtureCardGeneratorTests`: passed
- `swift test --filter LibraryStoreTests`: passed
- `swift test`: passed, 34 tests
- `./script/build_and_run.sh --verify`: passed
- `git diff --check`: passed
