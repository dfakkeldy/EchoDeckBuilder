# EchoDeckBuilder

Local-first app idea for turning an EPUB into an Echo-ready study deck.

## Why

Echo already has a strong reader model: imported EPUB content becomes `epub_block` rows, and some internal study-plan cards can point at those rows through `flashcard.source_block_id`.

The missing product gap is external deck creation. Echo's import path can now resolve source-anchored JSON and APKG cards back to EPUB blocks, so this app's job is to generate and export those anchored decks cleanly.

## Goal

Build a Mac-first tool that takes a private EPUB, creates balanced mixed flashcards for me, and exports a deck that can be anchored back to the EPUB sections Echo displays.

EchoDeckBuilder's Echo export target is Echo deck import vNext: every Echo-ready card should carry a portable source anchor shaped like `s<i>-b<j>`. Echo is responsible for resolving that portable suffix to the local `epub_block.id` for the selected book and storing it in `flashcard.source_block_id`.

Default deck profile:

- Size: balanced
- Audience: me
- Card types: mixed basic and cloze
- Source handling: paraphrased cards, no long source quotations
- Anchoring: every card should carry a source EPUB location

## License

EchoDeckBuilder is licensed under the GNU General Public License, version 3 or
later (`GPL-3.0-or-later`). See [`LICENSE`](LICENSE) and
[`LICENSE-APP-STORE-EXCEPTION.md`](LICENSE-APP-STORE-EXCEPTION.md) for the
additional App Store distribution permission.

## Product Direction

Build this as its own Mac app first, then add a small Echo integration once the file format is proven.

Current product stance: EchoDeckBuilder is a proof harness, not the intended long-term user-facing product. Its job is to prove the EPUB parsing, AI generation, review, and Echo deck export workflow in a smaller macOS app. Once the workflow is proven, the deck-authoring feature should be folded into Echo so Echo owns the library context, target media ID, source block resolution, persistence, privacy disclosures, and study experience.

Reasoning:

- Deck generation is an authoring workflow: import EPUB, chunk text, choose AI settings, review/edit cards, inspect anchors, dedupe, tag, and export.
- Echo should stay focused on reading, listening, reviewing, and showing anchored cards in context.
- A separate app can experiment with model providers, privacy controls, Anki export, and diagnostics without destabilizing Echo.
- Echo now has the focused integration this app needs: it imports Echo deck JSON vNext and resolves source anchors into `flashcard.source_block_id`.

Likely end state:

1. EchoDeckBuilder owns deck creation and review.
2. Echo imports finished decks and displays cards anchored to EPUB blocks.
3. A later Echo button can open EchoDeckBuilder for the current EPUB, or trigger a simplified built-in generator after the workflow is stable.

## MVP

1. Import an EPUB locally.
2. Extract spine-ordered XHTML into clean Markdown-like sections.
3. Split the book into stable blocks that can map to Echo's `epub_block` model.
4. Generate candidate cards from each section.
5. Preserve a source anchor per card:
   - canonical Echo portable block suffix, for example `s4-b12`
   - EPUB spine href
   - fragment/id when present
   - section heading
   - normalized text fingerprint
   - optional local Echo `epub_block.id` only as a validation/matching aid, never as the exported canonical anchor
6. Let me review, edit, accept, reject, and tag cards.
7. Export:
   - Anki TSV/APKG for normal Anki use
   - Echo deck JSON vNext with per-card `sourceAnchor`
   - APKG with archive-root `echo-import.json` sidecar for Echo-aware APKG import

## Echo Integration Finding

From the Echo repo inspection:

- `Shared/Database/Flashcard.swift` has `sourceBlockID`.
- `Shared/Database/Schema_V1.swift` creates `flashcard.source_block_id`.
- `EchoCore/ViewModels/ReaderFeedViewModel.swift` prefers `sourceBlockID` when placing card extras in the reader feed.
- `Shared/Database/DAOs/StudyPlanDAO.swift` creates internal study-plan cards with `sourceBlockID`.
- `EchoCore/Models/FlashcardDeckImport.swift` accepts optional source anchors and optional timestamps for imported cards.
- `EchoCore/Services/DeckImportService.swift` resolves `sourceAnchor` against `deck.targetMediaID` before insert.
- `EchoCore/Services/ApkgImportService.swift` reads optional Echo anchor metadata for APKG imports.

Conclusion: Echo supports EPUB-anchored cards internally and now has the anchor-first import path this app targets for fully Echo-ready exports.

## Echo Source Anchor Import Contract

The Echo-side import contract for this app is based on `docs/superpowers/specs/2026-06-25-deck-import-source-anchors-design.md` in the Echo repo.

Canonical source anchors use Echo's portable EPUB block suffix:

```text
s<i>-b<j>
```

Example Echo deck JSON vNext:

```json
{
  "deckName": "Everything but the Code",
  "targetMediaID": "file:///path/or/echo/audiobook/id",
  "cards": [
    {
      "frontText": "What is the core purpose of a strategic anchor?",
      "backText": "It gives you a clear decision rule for choosing work that advances your goal.",
      "triggerTiming": "manualOnly",
      "sourceAnchor": "s4-b12"
    }
  ]
}
```

Example Echo-aware APKG sidecar at archive root, named `echo-import.json`:

```json
{
  "formatVersion": 1,
  "targetMediaID": "file:///path/or/echo/audiobook/id",
  "cards": [
    {
      "cardID": 1712345678901,
      "noteGUID": "anki-note-guid",
      "sourceAnchor": "s4-b12",
      "startTime": 0,
      "endTime": 0,
      "triggerTiming": "manualOnly"
    }
  ]
}
```

Echo-side import behavior this app depends on:

1. `FlashcardDeckImport.ImportedCard` accepts optional `sourceAnchor`, `startTime`, and `endTime`.
2. `DeckImportService` resolves `sourceAnchor` against `deck.targetMediaID`.
3. A JSON card with a resolved `sourceAnchor` does not need `startTime` or `endTime`; Echo stores a schema-compatible `mediaTimestamp` placeholder and keeps `endTimestamp` nil.
4. A source-only JSON card whose anchor cannot resolve fails validation instead of importing without a placement anchor.
5. `.apkg` import reads optional `echo-import.json` and maps entries by Anki `cardID`, then `noteGUID`.
6. A shared `EPUBSourceAnchorResolver` accepts canonical suffixes like `s4-b12`, accepts legacy full IDs by stripping to the suffix, rebuilds the local `epub-\(targetMediaID)-\(suffix)` ID, and validates both `id` and `audiobook_id`.
7. `FlashcardDAO.syncToTimeline` writes `TimelineItem.epubBlockID` for anchored imported cards.
8. Existing timestamped JSON and APKG decks keep importing unchanged.

Out of scope for this vNext contract:

- Native EPUB `href#fragment` anchors.
- Persisting XHTML element-ID to block-ID maps.
- Reparsing EPUBs during Echo deck import.
- Adding a foreign key to `flashcard.source_block_id`.

## App Shape

Start with a SwiftUI macOS app:

- Sidebar: imported EPUBs and generated decks
- Main editor: section list, cards for selected section, accept/reject controls
- Inspector: source anchor, tags, card type, prompt/model settings
- Export panel: Anki TSV/APKG, Echo JSON vNext, diagnostics report

Local-first privacy rules:

- EPUB extraction happens locally.
- The user explicitly chooses any AI provider.
- The current MVP generator is deterministic and local; real AI provider selection is intentionally out of scope for this first build.
- The app sends only selected chunks, not the entire book by default.
- Generated cards should paraphrase source material and avoid long quotations.
- Private copyrighted material must never be uploaded, shared, or bundled into examples.

The local CLI generation providers are developer proof paths, not local-first production features. Selecting Claude CLI or Codex CLI may send selected source text through the user's configured CLI provider. The final Echo feature must make this explicit before generation, and production hosted AI should be handled through Echo-owned consent, entitlement, metering, and privacy flows.

## Implementation Notes

Good first milestones:

1. CLI prototype: EPUB to sections JSON.
2. CLI prototype: sections JSON to reviewed-card JSON using a fixture instead of live AI.
3. Echo matching prototype: source location to `epub_block.id`.
4. Echo JSON vNext proposal and importer patch in Echo.
5. Mac SwiftUI shell around the pipeline.

Avoid third-party dependencies until the first pipeline works with standard library tools and Echo's existing patterns.

## Build And Run

Run tests:

```bash
swift test
```

Build and launch the macOS app:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```
