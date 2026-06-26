## Task 2 Report: Prompt Builder And Draft Mapping

### What I implemented or attempted
- Added `FoundationModelCardPrompt` in `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`.
- Added deterministic prompt instructions, prompt assembly, and excerpt truncation with sentence-boundary preference.
- Added `GeneratedCardDraft` and `GeneratedCardDraftMapper` in `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`.
- Added deterministic draft-to-`DeckCard` mapping that trims front/back text, preserves `section.id` and `sourceAnchor`, keeps `reviewState` at `.draft`, and merges default tags with deduplication.
- Added the requested tests in:
  - `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`
  - `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`

### Tests run and results
- `swift test --filter FoundationModelCardPromptTests` -> PASS
- `swift test --filter GeneratedCardDraftTests` -> PASS
- `swift test` -> PASS

### TDD Evidence
#### RED
Command:
```bash
swift test --filter FoundationModelCardPromptTests
```
Output excerpt:
```text
/Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift:15:22: error: cannot find 'FoundationModelCardPrompt' in scope
```

Command:
```bash
swift test --filter GeneratedCardDraftTests
```
Output excerpt:
```text
/Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift:14:21: error: cannot find 'GeneratedCardDraft' in scope
/Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift:21:34: error: cannot find 'GeneratedCardDraftMapper' in scope
```

#### GREEN
Command:
```bash
swift test --filter FoundationModelCardPromptTests
```
Output excerpt:
```text
Test Suite 'FoundationModelCardPromptTests' passed
Executed 4 tests, with 0 failures
```

Command:
```bash
swift test --filter GeneratedCardDraftTests
```
Output excerpt:
```text
Test Suite 'GeneratedCardDraftTests' passed
Executed 3 tests, with 0 failures
```

Command:
```bash
swift test
```
Output excerpt:
```text
Test Suite 'All tests' passed
Executed 47 tests, with 0 failures
```

### Files changed
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`

### Self-review findings
- Confirmed the implementation matches the brief’s literal prompt/instruction strings and default tag order.
- Confirmed no `FoundationModels` import or call was introduced.
- Confirmed mapping remains app-owned and deterministic through explicit trimming, anchor preservation, and stable tag merging.
- No issues found in the scoped changes after diff review and full test run.

### Issues or concerns
- No current concerns.

## Task 2 Fix Follow-Up: Prompt-Length Edge Case

### Fix summary
- Updated `FoundationModelCardPrompt.excerpt(from:maxCharacters:)` to return an empty string when `maxCharacters` is `0` or negative, instead of returning the full trimmed source text.
- Added a focused regression test covering both zero and negative character limits.
- Preserved all existing prompt construction behavior for positive limits, including deterministic trimming and sentence-boundary preference.

### Tests run and results
- `swift test --filter FoundationModelCardPromptTests` -> PASS (`Executed 5 tests, with 0 failures`)
- `swift test` -> PASS (`Executed 48 tests, with 0 failures`)

### Files changed
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`
- `/Users/dfakkeldy/.codex/worktrees/202c/EchoDeckBuilder/.superpowers/sdd/task-2-report.md`

### Self-review findings/concerns
- Verified the fix is scoped strictly to the non-positive length edge case called out in review.
- Verified no `FoundationModels` import or usage was introduced.
- No additional concerns after the targeted and full test runs.
