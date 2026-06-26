# Foundation Models Manual Test Checklist

Use this checklist on a Mac running macOS 26 or newer with an Apple Intelligence-capable processor.

## Availability

- Launch EchoDeckBuilder.
- Open the inspector.
- Select Fixture.
- Confirm availability reads "Fixture generator ready".
- Select Foundation Models.
- Confirm one of these messages appears:
  - "Foundation Models ready"
  - "Foundation Models requires an Apple Intelligence-capable Mac"
  - "Turn on Apple Intelligence in System Settings to use Foundation Models"
  - "Apple Intelligence is still preparing the language model"
  - "Foundation Models does not support the current language"
  - "Foundation Models is unavailable"

## Happy Path

- Import a small EPUB with at least three paragraph blocks.
- Select Foundation Models.
- Confirm Generate Cards is enabled only when availability reads "Foundation Models ready".
- Generate cards.
- Confirm every generated card is a draft.
- Confirm every generated card keeps its section source anchor, such as `s1-b1`.
- Confirm generated text is paraphrased and does not copy long source passages.
- Accept one generated card.
- Set a target media ID.
- Export Echo deck JSON.
- Confirm the exported card includes `sourceAnchor` and does not include full source text or a local Echo block ID.

## Fallbacks

- Select Foundation Models on a Mac or OS version where it is unavailable.
- Confirm Generate Cards is disabled and the availability message explains why.
- Select Fixture.
- Confirm Generate Cards works.

## Long Sections

- Import an EPUB with a long paragraph block.
- Generate with Foundation Models.
- Confirm the app does not crash.
- Confirm generation either produces a draft card or reports a readable failure in the status text.
