Status: completed

Summary:
- Added inspector generation controls for provider, model, batch size, cards per batch, and image mode using the existing `Form` and `Section` style.
- Added latest book brief summary and generation warning display in the inspector when generation metadata is present.
- Added visual review controls in card review for visual priority, editable image prompt, and editable alt text backed by `LibraryStore.update(cardID:mutate:)`.

Verification:
- `./script/build_and_run.sh --verify` (pre-edit): passed
- `swift build`: passed
- `swift test`: passed (62 tests)
- `./script/build_and_run.sh --verify` (post-edit): passed

Commit SHA:
- Final SHA is reported in task handoff/output. It is not embedded here because adding the SHA to this file would change the commit hash itself.

Concerns:
- None
