# EchoDeckBuilder

Local-first app idea for turning an EPUB into an Echo-ready study deck.

## Why

Echo already has a strong reader model: imported EPUB content becomes `epub_block` rows, and some internal study-plan cards can point at those rows through `flashcard.source_block_id`.

The missing product gap is external deck creation. Echo's current JSON deck importer is timestamp-based: it imports `startTime` and `endTime`, then inserts cards with `sourceBlockID: nil`. APKG import also creates cards without EPUB block anchors. So an external deck can be imported today, but it is not fully Echo-ready unless Echo gets an import path that accepts and resolves EPUB block anchors.

## Goal

Build a Mac-first tool that takes a private EPUB, creates balanced mixed flashcards for me, and exports a deck that can be anchored back to the EPUB sections Echo displays.

Default deck profile:

- Size: balanced
- Audience: me
- Card types: mixed basic and cloze
- Source handling: paraphrased cards, no long source quotations
- Anchoring: every card should carry a source EPUB location

## MVP

1. Import an EPUB locally.
2. Extract spine-ordered XHTML into clean Markdown-like sections.
3. Split the book into stable blocks that can map to Echo's `epub_block` model.
4. Generate candidate cards from each section.
5. Preserve a source anchor per card:
   - EPUB spine href
   - fragment/id when present
   - section heading
   - normalized text fingerprint
   - optional Echo `epub_block.id` after matching against an imported Echo database
6. Let me review, edit, accept, reject, and tag cards.
7. Export:
   - Anki TSV/APKG for normal Anki use
   - Echo deck JSON vNext for source-block-aware import

## Echo Integration Finding

From the Echo repo inspection:

- `Shared/Database/Flashcard.swift` has `sourceBlockID`.
- `Shared/Database/Schema_V1.swift` creates `flashcard.source_block_id`.
- `EchoCore/ViewModels/ReaderFeedViewModel.swift` prefers `sourceBlockID` when placing card extras in the reader feed.
- `Shared/Database/DAOs/StudyPlanDAO.swift` creates internal study-plan cards with `sourceBlockID`.
- `EchoCore/Models/FlashcardDeckImport.swift` only defines `startTime` and `endTime` for imported cards.
- `EchoCore/Services/DeckImportService.swift` currently inserts imported JSON cards with `sourceBlockID: nil`.
- `EchoCore/Services/ApkgImportService.swift` also imports APKG cards with `sourceBlockID: nil`.

Conclusion: Echo supports EPUB-anchored cards internally, but the external deck import format needs a vNext schema before this app can produce a fully Echo-ready import.

## Draft Echo Deck JSON vNext

```json
{
  "deckName": "Everything but the Code",
  "targetMediaID": "file:///path/or/echo/audiobook/id",
  "source": {
    "kind": "epub",
    "title": "Everything but the Code",
    "author": "Paul Hudson",
    "fingerprint": "stable-book-fingerprint"
  },
  "cards": [
    {
      "frontText": "What is the core purpose of a strategic anchor?",
      "backText": "It gives you a clear decision rule for choosing work that advances your goal.",
      "cardType": "basic",
      "triggerTiming": "manualOnly",
      "source": {
        "spineHref": "chapter.xhtml",
        "fragmentID": "optional-html-id",
        "heading": "Vision and Goals",
        "textFingerprint": "stable-block-fingerprint",
        "echoBlockID": "optional-when-known"
      }
    }
  ]
}
```

Echo-side work needed:

1. Add optional source fields to `FlashcardDeckImport.ImportedCard`.
2. Resolve `echoBlockID` directly when present and valid.
3. Otherwise resolve by `spineHref`, `fragmentID`, heading, and text fingerprint.
4. Store the resolved value in `Flashcard.sourceBlockID`.
5. Keep `startTime` and `endTime` as optional fallback fields for audiobook-only decks.

## App Shape

Start with a SwiftUI macOS app:

- Sidebar: imported EPUBs and generated decks
- Main editor: section list, cards for selected section, accept/reject controls
- Inspector: source anchor, tags, card type, prompt/model settings
- Export panel: Anki TSV/APKG, Echo JSON vNext, diagnostics report

Local-first privacy rules:

- EPUB extraction happens locally.
- The user explicitly chooses any AI provider.
- The app sends only selected chunks, not the entire book by default.
- Generated cards should paraphrase source material and avoid long quotations.
- Private copyrighted material must never be uploaded, shared, or bundled into examples.

## Implementation Notes

Good first milestones:

1. CLI prototype: EPUB to sections JSON.
2. CLI prototype: sections JSON to reviewed-card JSON using a fixture instead of live AI.
3. Echo matching prototype: source location to `epub_block.id`.
4. Echo JSON vNext proposal and importer patch in Echo.
5. Mac SwiftUI shell around the pipeline.

Avoid third-party dependencies until the first pipeline works with standard library tools and Echo's existing patterns.
