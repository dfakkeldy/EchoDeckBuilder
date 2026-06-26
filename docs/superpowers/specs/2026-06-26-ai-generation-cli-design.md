# EchoDeckBuilder AI Generation Design

Date: 2026-06-26
Status: Approved for planning

## Goal

Add a real-AI generation path that can be tested locally through `claude` and
`codex` CLI, while preserving a clean route to a future subscription product
with included AI quota.

The app should not become section-by-section trivia generation. It should build a
book-level understanding first, then generate source-anchored cards from
chapter-sized batches.

## Product Direction

Long term, EchoDeckBuilder should be a subscription app with included AI quota.
Users pay for EchoDeckBuilder, and the production app calls a hosted backend that
owns provider API keys, usage metering, abuse controls, and cost limits.

For the current development phase, the app should use local developer-only AI
adapters:

- `claude -p` for non-interactive Claude CLI generation.
- `codex exec` for non-interactive Codex CLI generation.

These adapters are for testing the pipeline, prompts, schemas, and review UX.
They are not the production billing model and should be clearly separated from
the later hosted AI provider.

## Core Workflow

EchoDeckBuilder keeps EPUB extraction local. Imported books are converted into
spine-ordered source blocks with stable portable anchors, such as `s4-b12`.

Each time the user runs AI generation, the app creates a fresh generation run
from the current settings:

- selected book or selected EPUB scope
- provider adapter
- model, when supported
- target card count or density
- card type mix
- audience and tone
- memorable image toggle
- selected sections or chapters

The generation run has four stages:

1. Prepare source.
2. Regenerate book context.
3. Generate batch candidates.
4. Review candidates into the saved deck.

## Context Pyramid

The model should see the big picture without losing source anchoring.

```text
Whole book brief
|
Chapter or neighboring-section batch context
|
Individual source-anchored cards
|
Optional memorable image prompt for high-value cards
```

### Book Brief Pass

The app sends a compact representation of the selected scope:

- title and known metadata
- table of contents or section heading outline
- representative text from relevant source blocks
- current generation settings
- accepted card summaries, only to avoid duplicates

The model returns a fresh book brief for that generation run. The brief should
capture:

- main themes
- key concepts
- recurring terms
- argument or narrative flow
- what is worth remembering
- areas that deserve cards
- areas that should be skipped

The brief is regenerated every time generation settings change or the user starts
a new generation run. Raw EPUB extraction may be cached, but AI-derived context is
settings-bound.

### Batch Generation Pass

After the brief is produced, the app sends chapter-sized batches or neighboring
section groups. A reasonable first target is 8 to 20 source blocks per request,
adjusted by text length.

Each batch prompt includes:

- the fresh book brief
- source blocks for the current batch
- each block's canonical source anchor
- accepted card summaries to avoid duplicates
- explicit card-writing directions
- JSON schema or output contract
- image instructions when the memorable image toggle is enabled

The model may use the book brief for context, but every generated card must point
to a concrete source anchor from the current batch.

## Review State

Accepted cards are durable deck content. Regeneration must never delete or
rewrite them.

Current draft candidates are replaceable. Starting a new generation run replaces
the active draft set with fresh candidates.

```text
Saved Deck
- accepted cards
- protected from regeneration
- exportable

Current Draft Run
- latest generated candidates
- replaced on regeneration
- not exportable until accepted
```

Rejected cards do not remain in the active UI after regeneration. They may be
omitted entirely for the first AI version unless diagnostics need them.

Accepted cards may be summarized and sent to later generation runs as
deduplication context. The model should treat them as protected examples, not as
content to revise. A separate future command can support explicit accepted-card
revision.

## Output Schema

The AI output should be validated locally before it reaches the review UI.

The first schema should use this top-level shape:

```json
{
  "run": {
    "provider": "claude-cli",
    "model": "default",
    "sourceScope": "selected-book",
    "imageMode": "prompts"
  },
  "bookBrief": {
    "summary": "Compact book-level explanation.",
    "themes": ["theme"],
    "keyConcepts": ["concept"],
    "argumentFlow": ["step"],
    "skipAreas": ["area"]
  },
  "cards": [],
  "warnings": []
}
```

The generation result includes:

- run metadata
- structured book brief
- batch candidate cards
- warnings

Each card candidate includes:

- stable local candidate ID assigned by the app
- source anchor
- card kind: `basic` or `cloze`
- front text
- back text
- cloze text when applicable
- tags
- importance score
- confidence score
- rationale for why the card matters
- optional visual metadata

The app rejects or quarantines cards when:

- JSON is invalid.
- required fields are missing.
- source anchor is malformed.
- source anchor is outside the current batch.
- front or back text is empty.
- the card contains long source quotations.
- cloze syntax is invalid for a cloze card.

## Memorable Image Toggle

The first AI version should not generate actual images directly. It should ask
the model for image metadata on high-value cards.

When enabled, the card schema can include:

```json
{
  "visual": {
    "priority": "high",
    "imagePrompt": "A memorable visual metaphor for the concept.",
    "altText": "Accessible description of the visual."
  }
}
```

The visual field should be optional. The model should only add it to the most
important points, not every card.

Later, the hosted AI backend can turn approved image prompts into generated image
attachments according to subscription tier and quota.

## Provider Architecture

The existing `CardGenerator` protocol is the right seam for generation behavior.
The app should evolve toward:

```text
CardGenerator
|- FixtureCardGenerator
|- LocalClaudeCLIGenerator
|- LocalCodexCLIGenerator
`- HostedAIGenerator
```

The local CLI generators should share as much infrastructure as possible:

- prompt package builder
- schema builder
- process runner
- JSON decoder and validator
- generation diagnostics

Provider-specific code should only handle command shape and output extraction.

### Claude CLI Adapter

Use `claude -p` for non-interactive output. Its `--json-schema` option should be
the first path to test strict structured generation.

The adapter should avoid granting file or shell tools to the model. EPUB source
text should be passed as prompt input, not by letting the model browse the
project or filesystem.

### Codex CLI Adapter

Use `codex exec` for non-interactive output. Its `--output-schema <FILE>` option
can validate the final response shape.

Run Codex in an isolated working directory for generation artifacts. The adapter
should not give Codex permission to edit the app repository during deck
generation.

### Hosted AI Adapter

The production adapter should call an EchoDeckBuilder backend. The backend owns:

- provider API keys
- subscription entitlement checks
- monthly quota
- per-run spending caps
- image quota
- rate limiting
- abuse controls
- provider-specific retry and fallback behavior

The Mac app should receive structured generation results from the backend using
the same internal schema as the local CLI adapters.

## Privacy And Security

EPUB extraction happens locally. The app should only send selected chunks, not
the entire book by default.

Before sending content to any AI provider, the UI should clearly show:

- selected scope
- destination provider or local CLI
- whether images are enabled
- approximate amount of text being sent

The app should treat EPUB content as untrusted prompt context. Source text must
be delimited as source material, not instructions. Model output must be parsed
and validated deterministically before it affects app state.

For production, provider API keys must never ship in the Mac app. They belong on
the backend. Any local credentials used for developer testing should stay in the
developer's normal CLI auth store or macOS Keychain and should not be exported in
deck files or diagnostics.

## Error Handling

Generation failures should preserve accepted cards and leave the saved deck
unchanged.

The app should show actionable errors for:

- CLI not installed
- CLI not authenticated
- command timeout
- schema validation failure
- empty model output
- malformed JSON
- provider rate limit or quota failure
- source anchor validation failure

Partial batch failures should not discard successful accepted cards. The current
draft run can include per-batch warnings and allow retrying failed batches.

## Testing

Unit tests should cover:

- prompt package construction
- schema encoding
- JSON decoding
- source anchor validation
- rejection of out-of-batch anchors
- rejection of malformed cloze cards
- accepted-card preservation across regeneration
- draft replacement on regeneration

Integration-style tests can use fixture CLI output first. Live CLI tests should
be opt-in because they require local auth and may consume quota.

## Out Of Scope

This design does not implement:

- production hosted backend
- StoreKit subscription paywall
- real provider API billing
- actual image generation
- APKG media attachment packaging
- editing accepted cards through AI
- browser automation of ChatGPT, Claude, or Gemini consumer sites

## First-Version Choices

- Persist accepted deck cards and the latest current draft run. Do not build
  generation run history in the first AI version.
- Keep pricing, quota, StoreKit, and hosted backend details out of the local CLI
  implementation plan.
- Show image prompts in the review UI and diagnostics report. Do not export image
  prompt metadata to Anki or Echo deck files until media attachment behavior is
  designed.
- Use Claude CLI as the first live adapter, then add Codex CLI after the shared
  prompt and schema validation path is stable.
