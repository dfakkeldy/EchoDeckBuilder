# Echo Fold-In Migration Map

EchoDeckBuilder is the proving ground for deck authoring. Echo is the intended long-term home of the feature.

## Keep Proving In Builder

- EPUB parsing parity with Echo block IDs.
- Prompt and schema iteration for AI-generated draft cards.
- Review/edit/accept/reject workflow experiments.
- Echo JSON export validation.
- Manual and automated round-trip fixtures.

## Move Into Echo

- Current-book deck generation entry point.
- Target media ID selection, because Echo already knows the current audiobook or EPUB record.
- Final card insertion and persistence.
- Study deck management.
- Privacy, subscription, and hosted AI entitlement UI.
- Reader context display for generated source-anchored cards.

## Builder To Echo Mapping

| Builder Unit | Echo Destination | Notes |
| --- | --- | --- |
| `EchoCompatibleEPUBParser` | Existing Echo EPUB parser / resolver path | Prefer Echo's canonical parser rather than maintaining two divergent copies. |
| `BookSection` | Echo EPUB block records or lightweight generation DTOs | Native Echo should generate from already-imported blocks. |
| `DeckCard` | `Flashcard` draft/review model or deck-import DTO | Echo should not require exporting/importing JSON for native generation. |
| `CardGenerator` and CLI adapters | Echo AI generation service layer | Keep provider seams; production hosted AI belongs behind Echo-owned consent and entitlement checks. |
| `EchoDeckJSONExporter` | Import/export compatibility layer | Useful for external deck import, but native authoring can insert directly. |
| SwiftUI review views | Echo deck authoring UI | Rebuild with Echo navigation, persistence, and reader context. |

## Migration Principle

Builder proves behavior. Echo ships the feature.

## Proof Completion Criteria

Builder is ready to fold into Echo when:

- Parser parity tests pass.
- Builder exports source-only Echo deck JSON.
- Echo imports that JSON for the same EPUB.
- Echo resolves at least one generated card to a non-nil `sourceBlockID`.
- Non-local generation providers disclose that source text may leave the device.
- The remaining work is Echo-native UI and persistence, not proof of anchor mechanics.
