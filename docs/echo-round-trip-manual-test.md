# Echo Round-Trip Manual Test

Use this checklist to prove EchoDeckBuilder exports cards that Echo resolves back to EPUB blocks.

## Prerequisites

- Latest EchoDeckBuilder `main`.
- Latest Echo branch that includes Echo deck JSON vNext source-anchor import.
- A small EPUB safe to use locally.
- The same EPUB imported into Echo before importing the generated deck JSON.

## Steps

1. Launch EchoDeckBuilder:

   ```bash
   ./script/build_and_run.sh
   ```

2. Import the EPUB.
3. Generate cards with `Fixture` first.
4. Accept at least one card.
5. In Echo, identify the imported EPUB media ID. For the proof run, use the exact `audiobook_id` that Echo stores for the imported EPUB.
6. Enter that value as `Target media ID` in EchoDeckBuilder.
7. Export Echo deck JSON.
8. In Echo, import the exported JSON deck.
9. Confirm Echo reports imported cards and no unresolved source-anchor warning for the accepted card.
10. Inspect the imported card in Echo and confirm `sourceBlockID` resolves to an `epub-<targetMediaID>-s<i>-b<j>` block.
11. Open the reader/feed context and confirm the card appears in the source block context.

## Expected Result

- Echo imports the deck.
- At least one card has a non-nil `sourceBlockID`.
- The `sourceBlockID` suffix matches the exported `sourceAnchor`.
- The card appears in Echo's source-aware reader/feed context.

## Failure Notes

- If Echo reports `targetAudiobookHasNoEPUBBlocks`, the target media ID does not match the imported EPUB's `audiobook_id`.
- If Echo reports `sourceAnchorUnresolved`, Builder and Echo disagree about parser block offsets for the EPUB.
- If Echo imports but the card has no reader/feed placement, inspect `FlashcardDAO.syncToTimeline`.

## Latest Verified Proof Run

- Date: 2026-06-27
- EchoDeckBuilder commit: `3b1a9a7` code state before this proof-record docs commit.
- Echo commit: `6bcde7e` in `/Users/dfakkeldy/.codex/worktrees/d883/Echo`.
- EPUB used: Synthetic XCTest fixtures and in-memory Echo `epub_block` rows only; no private EPUB text or manual local book was used.
- Generation provider: Fixture/synthetic test data.
- Exported cards: EchoDeckBuilder exporter tests validated a source-only accepted card with `sourceAnchor` and no source text or Echo block ID; full Builder suite passed 107 tests.
- Echo imported cards: 1 card in `DeckImportServiceTests.importDeckVNextResolvesSourceAnchor()`.
- Echo resolved source-anchored cards: 1 card resolved to `epub-book-a-s1-b2`; `FlashcardDAOSchedulerTests.syncToTimelineCopiesSourceBlockID()` also verified timeline propagation.
- Notes: Automated verification passed with `swift test`, `./script/build_and_run.sh --verify`, and Echo's focused `xcodebuild test` filters. The hands-on UI checklist above still needs one local EPUB imported into both apps to prove the end-user click path.
