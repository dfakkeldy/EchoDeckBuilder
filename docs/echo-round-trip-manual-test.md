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
