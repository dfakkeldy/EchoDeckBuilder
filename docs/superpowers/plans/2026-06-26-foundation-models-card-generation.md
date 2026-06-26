# Foundation Models Card Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, availability-gated Foundation Models card generator that creates local AI draft cards from imported EPUB sections while preserving the fixture fallback and deterministic source anchors.

**Architecture:** Keep `CardGenerator` as the store-facing abstraction. Add provider selection, availability reporting, prompt/mapping helpers, and a Foundation Models generator compiled behind `#if canImport(FoundationModels)` and run behind `@available(macOS 26.0, *)`. The model generates only draft card text and tags; anchors, review state, and exports remain deterministic app logic.

**Tech Stack:** SwiftPM, Swift 6, SwiftUI for macOS 14+, XCTest, Foundation Models on macOS 26+ when available, no third-party packages.

## Global Constraints

- Do not raise the package platform floor above macOS 14 for this phase.
- Keep EPUB content on device when using the Foundation Models provider.
- Preserve deterministic source anchors. The model generates card content only; `BookSection.anchor` remains the exported `sourceAnchor`.
- Preserve the existing fixture generator as the default fallback and as the unit-test baseline.
- Make provider availability explicit in the UI so unsupported Macs, disabled Apple Intelligence, unavailable model assets, and unsupported languages degrade gracefully.
- Keep generated cards paraphrased and short, avoiding long quotations from copyrighted source material.
- Do not add cloud AI providers.
- Do not train or ship Foundation Models custom adapters.
- Do not add Create ML, Vision, OCR, or text-to-speech features.
- Do not let the model create, rewrite, or validate Echo source anchors.
- Do not replace the review workflow; generated cards remain drafts until accepted.
- Do not implement APKG sidecar generation in this phase.

---

## Scope Check

This plan implements one subsystem: optional Foundation Models card generation. It does not change EPUB parsing, Echo JSON semantics, Anki TSV export, APKG generation, or Echo import behavior. Each task below leaves the app buildable and testable.

## File Structure

- `Sources/EchoDeckBuilder/Services/CardGenerationProvider.swift`: user-selectable generator provider enum and display labels.
- `Sources/EchoDeckBuilder/Services/CardGenerationAvailability.swift`: app-owned availability and generation error values with user-facing messages.
- `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`: resolves a provider into availability and a concrete `CardGenerator`.
- `Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`: deterministic prompt and instruction construction for section-to-card generation.
- `Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`: app-owned draft value and mapper from draft content to anchored `DeckCard`.
- `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`: Foundation Models availability bridge behind compile-time and runtime gates.
- `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`: Foundation Models-backed `CardGenerator`.
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`: provider selection, availability-gated generation, resolver injection.
- `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`: app uses the default resolver instead of a fixed fixture generator.
- `Sources/EchoDeckBuilder/Views/InspectorView.swift`: provider picker and selected-provider availability text.
- `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`: provider, availability, and resolver tests.
- `Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`: prompt/excerpt tests.
- `Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`: draft-to-card mapping tests.
- `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`: generation availability and provider-selection store tests.
- `docs/foundation-models-manual-test.md`: manual verification checklist for Apple Intelligence-capable environments.

---

### Task 1: Provider Selection And Resolver Skeleton

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/CardGenerationProvider.swift`
- Create: `Sources/EchoDeckBuilder/Services/CardGenerationAvailability.swift`
- Create: `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- Modify: `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- Modify: `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`
- Create: `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`
- Modify: `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: existing `CardGenerator.generateCards(for:) async throws -> [DeckCard]`
- Produces: `CardGenerationProvider`
- Produces: `CardGenerationAvailability`
- Produces: `CardGenerationError`
- Produces: `CardGeneratorResolving`
- Produces: `DefaultCardGeneratorResolver`
- Produces: `FixedCardGeneratorResolver`
- Produces: `LibraryStore.selectedGenerationProvider`
- Produces: `LibraryStore.generationAvailability`

- [ ] **Step 1: Write failing provider and resolver tests**

Create `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`:

```swift
import XCTest
@testable import EchoDeckBuilder

final class CardGenerationProviderTests: XCTestCase {
    func testProviderDisplayNamesAreStable() {
        XCTAssertEqual(CardGenerationProvider.fixture.displayName, "Fixture")
        XCTAssertEqual(CardGenerationProvider.foundationModels.displayName, "Foundation Models")
        XCTAssertEqual(CardGenerationProvider.allCases, [.fixture, .foundationModels])
    }

    func testAvailabilityFactoriesPreserveMessages() {
        let available = CardGenerationAvailability.available("Fixture generator ready")
        let unavailable = CardGenerationAvailability.unavailable("Foundation Models requires macOS 26+")

        XCTAssertTrue(available.isAvailable)
        XCTAssertEqual(available.message, "Fixture generator ready")
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(unavailable.message, "Foundation Models requires macOS 26+")
    }

    func testFixedResolverAlwaysReturnsInjectedGenerator() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "A useful source block.",
            anchor: anchor
        )
        let expectedCard = DeckCard(
            sectionID: section.id,
            frontText: "Generated front",
            backText: "Generated back",
            kind: .basic,
            sourceAnchor: anchor
        )
        let resolver = FixedCardGeneratorResolver(generator: StaticCardGenerator(cards: [expectedCard]))

        XCTAssertTrue(resolver.availability(for: .fixture).isAvailable)
        XCTAssertTrue(resolver.availability(for: .foundationModels).isAvailable)

        let cards = try await resolver.generator(for: .foundationModels).generateCards(for: [section])
        XCTAssertEqual(cards, [expectedCard])
    }
}

private struct StaticCardGenerator: CardGenerator {
    let cards: [DeckCard]

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        cards
    }
}
```

Append these tests to `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift` before `private func makeFixture(...)`:

```swift
    func testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .foundationModels,
            generatorResolver: UnavailableFoundationModelResolver()
        )

        XCTAssertFalse(store.canGenerateCards)
        XCTAssertEqual(store.generationAvailability.message, "Foundation Models requires macOS 26+")

        store.generateCardsForSelectedBook()

        XCTAssertEqual(store.statusMessage, "Foundation Models requires macOS 26+")
        XCTAssertFalse(store.isGeneratingCards)
        XCTAssertEqual(store.cards, [])
    }

    func testSelectedProviderUsesResolverGenerator() async throws {
        let fixture = try makeFixture()
        let generatedCard = DeckCard(
            sectionID: fixture.section.id,
            frontText: "Foundation front",
            backText: "Foundation back",
            kind: .basic,
            tags: ["generated", "foundation-models"],
            sourceAnchor: fixture.section.anchor
        )
        let resolver = ProviderRecordingResolver(cards: [generatedCard])
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .foundationModels,
            generatorResolver: resolver
        )

        store.generateCardsForSelectedBook()

        try await Task.sleep(for: .milliseconds(25))
        let requestedProviders = await resolver.requestedProviders()

        XCTAssertEqual(requestedProviders, [.foundationModels])
        XCTAssertEqual(store.cards, [generatedCard])
        XCTAssertEqual(store.statusMessage, "Generated 1 draft cards")
    }
```

Append these helper resolvers near the other private test helpers in `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`:

```swift
private struct UnavailableFoundationModelResolver: CardGeneratorResolving {
    func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return .unavailable("Foundation Models requires macOS 26+")
        }
    }

    func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        FixtureCardGenerator()
    }
}

private actor ProviderRecordingResolver: CardGeneratorResolving {
    private let cards: [DeckCard]
    private var providers: [CardGenerationProvider] = []

    init(cards: [DeckCard]) {
        self.cards = cards
    }

    nonisolated func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        .available("\(provider.displayName) ready")
    }

    nonisolated func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        RecordingGenerator(owner: self, provider: provider, cards: cards)
    }

    func record(_ provider: CardGenerationProvider) {
        providers.append(provider)
    }

    func requestedProviders() -> [CardGenerationProvider] {
        providers
    }
}

private struct RecordingGenerator: CardGenerator {
    let owner: ProviderRecordingResolver
    let provider: CardGenerationProvider
    let cards: [DeckCard]

    func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        await owner.record(provider)
        return cards
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter CardGenerationProviderTests`

Expected: FAIL because `CardGenerationProvider`, `CardGenerationAvailability`, `FixedCardGeneratorResolver`, and `CardGeneratorResolving` are not defined.

Run: `swift test --filter LibraryStoreTests/testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability`

Expected: FAIL because `LibraryStore` does not accept `selectedGenerationProvider` or `generatorResolver`.

- [ ] **Step 3: Add provider and availability models**

Create `Sources/EchoDeckBuilder/Services/CardGenerationProvider.swift`:

```swift
import Foundation

public enum CardGenerationProvider: String, CaseIterable, Identifiable, Sendable {
    case fixture
    case foundationModels

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .fixture:
            return "Fixture"
        case .foundationModels:
            return "Foundation Models"
        }
    }
}
```

Create `Sources/EchoDeckBuilder/Services/CardGenerationAvailability.swift`:

```swift
import Foundation

public struct CardGenerationAvailability: Equatable, Sendable {
    public let isAvailable: Bool
    public let message: String

    public static func available(_ message: String) -> CardGenerationAvailability {
        CardGenerationAvailability(isAvailable: true, message: message)
    }

    public static func unavailable(_ message: String) -> CardGenerationAvailability {
        CardGenerationAvailability(isAvailable: false, message: message)
    }
}

public enum CardGenerationError: LocalizedError, Sendable {
    case unavailable(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        }
    }
}
```

- [ ] **Step 4: Add resolver skeleton**

Create `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`:

```swift
import Foundation

public protocol CardGeneratorResolving: Sendable {
    func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability
    func generator(for provider: CardGenerationProvider) -> any CardGenerator
}

public struct DefaultCardGeneratorResolver: CardGeneratorResolving {
    public init() {}

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return .unavailable("Foundation Models generator is not connected yet")
        }
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        switch provider {
        case .fixture:
            return FixtureCardGenerator()
        case .foundationModels:
            return UnavailableCardGenerator(message: availability(for: provider).message)
        }
    }
}

public struct FixedCardGeneratorResolver: CardGeneratorResolving {
    private let generator: any CardGenerator

    public init(generator: any CardGenerator) {
        self.generator = generator
    }

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        .available("\(provider.displayName) ready")
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        generator
    }
}

public struct UnavailableCardGenerator: CardGenerator {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        throw CardGenerationError.unavailable(message)
    }
}
```

- [ ] **Step 5: Update LibraryStore to use provider selection and resolver injection**

Modify `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`.

Add this stored property after `public var isInspectorPresented: Bool`:

```swift
    public var selectedGenerationProvider: CardGenerationProvider
```

Replace the generator property:

```swift
    private let generatorResolver: any CardGeneratorResolving
```

Replace the current initializer with these two initializers:

```swift
    public convenience init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        generator: any CardGenerator = FixtureCardGenerator()
    ) {
        self.init(
            sections: sections,
            cards: cards,
            selectedGenerationProvider: .fixture,
            generatorResolver: FixedCardGeneratorResolver(generator: generator)
        )
    }

    public init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        selectedGenerationProvider: CardGenerationProvider = .fixture,
        generatorResolver: any CardGeneratorResolving
    ) {
        self.sections = sections
        self.cards = cards
        self.selectedSectionID = nil
        self.selectedCardID = nil
        self.deckName = "Untitled Deck"
        self.targetMediaID = ""
        self.statusMessage = "Ready"
        self.isInspectorPresented = true
        self.selectedGenerationProvider = selectedGenerationProvider
        self.isGeneratingCards = false
        self.isImportingEPUB = false
        self.generatorResolver = generatorResolver

        if let firstCardID = cards.first?.id {
            selectCard(firstCardID)
        } else {
            selectSection(sections.first?.id)
        }
    }
```

Add this computed property near `selectedCard`:

```swift
    public var generationAvailability: CardGenerationAvailability {
        generatorResolver.availability(for: selectedGenerationProvider)
    }
```

Replace `canGenerateCards` with:

```swift
    public var canGenerateCards: Bool {
        !sections.isEmpty && !isGeneratingCards && !isImportingEPUB && generationAvailability.isAvailable
    }
```

In `generateCardsForSelectedBook()`, add this guard after the `isImportingEPUB` guard:

```swift
        let availability = generationAvailability
        guard availability.isAvailable else {
            statusMessage = availability.message
            return
        }
```

In `generateCardsForSelectedBook()`, replace:

```swift
        let generator = self.generator
```

with:

```swift
        let generator = generatorResolver.generator(for: selectedGenerationProvider)
```

- [ ] **Step 6: Update the app to use the default resolver**

In `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`, replace the store property:

```swift
    @State private var library = LibraryStore(generatorResolver: DefaultCardGeneratorResolver())
```

- [ ] **Step 7: Run focused tests**

Run: `swift test --filter CardGenerationProviderTests`

Expected: PASS.

Run: `swift test --filter LibraryStoreTests/testUnavailableSelectedProviderDisablesGenerationAndReportsAvailability`

Expected: PASS.

Run: `swift test --filter LibraryStoreTests/testSelectedProviderUsesResolverGenerator`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift \
  Sources/EchoDeckBuilder/Stores/LibraryStore.swift \
  Sources/EchoDeckBuilder/Services/CardGenerationProvider.swift \
  Sources/EchoDeckBuilder/Services/CardGenerationAvailability.swift \
  Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift \
  Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift \
  Tests/EchoDeckBuilderTests/LibraryStoreTests.swift
git commit -m "feat: add card generation provider selection"
```

---

### Task 2: Prompt Builder And Draft Mapping

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`
- Create: `Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`
- Create: `Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`
- Create: `Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`

**Interfaces:**
- Consumes: `BookSection`, `DeckCard`, `CardKind`
- Produces: `FoundationModelCardPrompt.instructions: String`
- Produces: `FoundationModelCardPrompt.prompt(for:maxCharacters:) -> String`
- Produces: `FoundationModelCardPrompt.excerpt(from:maxCharacters:) -> String`
- Produces: `GeneratedCardDraft`
- Produces: `GeneratedCardDraftMapper.deckCard(from:section:) -> DeckCard?`

- [ ] **Step 1: Write failing prompt tests**

Create `Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift`:

```swift
import XCTest
@testable import EchoDeckBuilder

final class FoundationModelCardPromptTests: XCTestCase {
    func testPromptIncludesSourceLocationAndTextWithoutInventingAnchors() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s4-b12"))
        let section = BookSection(
            spineIndex: 4,
            blockIndex: 12,
            heading: "Prompt Boundaries",
            text: "Clear instructions keep model output grounded in supplied source text.",
            anchor: anchor
        )

        let prompt = FoundationModelCardPrompt.prompt(for: section, maxCharacters: 500)

        XCTAssertTrue(prompt.contains("Source anchor: s4-b12"))
        XCTAssertTrue(prompt.contains("Heading: Prompt Boundaries"))
        XCTAssertTrue(prompt.contains("Spine index: 4"))
        XCTAssertTrue(prompt.contains("Block index: 12"))
        XCTAssertTrue(prompt.contains(section.text))
        XCTAssertTrue(prompt.contains("Do not create or change source anchors."))
    }

    func testExcerptTrimsWhitespaceAndPrefersSentenceBoundary() {
        let text = " First sentence has useful context. Second sentence is longer than the requested limit. Third sentence. "

        let excerpt = FoundationModelCardPrompt.excerpt(from: text, maxCharacters: 45)

        XCTAssertEqual(excerpt, "First sentence has useful context.")
    }

    func testExcerptFallsBackToCharacterLimitWhenNoSentenceBoundaryExists() {
        let text = "abcdefghijklmnopqrstuvwxyz"

        let excerpt = FoundationModelCardPrompt.excerpt(from: text, maxCharacters: 10)

        XCTAssertEqual(excerpt, "abcdefghij")
    }

    func testInstructionsRequireParaphrasingAndGrounding() {
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Only use the supplied EPUB section"))
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Paraphrase"))
        XCTAssertTrue(FoundationModelCardPrompt.instructions.contains("Do not copy long passages"))
    }
}
```

- [ ] **Step 2: Write failing draft mapping tests**

Create `Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift`:

```swift
import XCTest
@testable import EchoDeckBuilder

final class GeneratedCardDraftTests: XCTestCase {
    func testDraftMapsToDraftDeckCardWithSourceAnchorPreserved() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Context",
            text: "Context helps generated cards stay grounded.",
            anchor: anchor
        )
        let draft = GeneratedCardDraft(
            frontText: "Why should generated cards stay grounded?",
            backText: "Grounding keeps the card tied to the supplied source instead of model guesses.",
            kind: .basic,
            tags: [" Context ", "ai"]
        )

        let card = try XCTUnwrap(GeneratedCardDraftMapper.deckCard(from: draft, section: section))

        XCTAssertEqual(card.sectionID, section.id)
        XCTAssertEqual(card.sourceAnchor, anchor)
        XCTAssertEqual(card.reviewState, .draft)
        XCTAssertEqual(card.frontText, "Why should generated cards stay grounded?")
        XCTAssertEqual(card.backText, "Grounding keeps the card tied to the supplied source instead of model guesses.")
        XCTAssertEqual(card.kind, .basic)
        XCTAssertEqual(card.tags, ["generated", "foundation-models", "Context", "ai"])
    }

    func testDraftMapperRejectsEmptyFrontOrBack() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 1,
            heading: "Intro",
            text: "Short text.",
            anchor: anchor
        )

        XCTAssertNil(
            GeneratedCardDraftMapper.deckCard(
                from: GeneratedCardDraft(frontText: " ", backText: "Answer", kind: .basic, tags: []),
                section: section
            )
        )
        XCTAssertNil(
            GeneratedCardDraftMapper.deckCard(
                from: GeneratedCardDraft(frontText: "Question", backText: " ", kind: .basic, tags: []),
                section: section
            )
        )
    }

    func testDraftMapperDeduplicatesDefaultTags() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b2"))
        let section = BookSection(
            spineIndex: 1,
            blockIndex: 2,
            heading: "Intro",
            text: "Short text.",
            anchor: anchor
        )
        let draft = GeneratedCardDraft(
            frontText: "Front",
            backText: "Back",
            kind: .cloze,
            tags: ["generated", "foundation-models", "generated", "deck"]
        )

        let card = try XCTUnwrap(GeneratedCardDraftMapper.deckCard(from: draft, section: section))

        XCTAssertEqual(card.kind, .cloze)
        XCTAssertEqual(card.tags, ["generated", "foundation-models", "deck"])
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter FoundationModelCardPromptTests`

Expected: FAIL because `FoundationModelCardPrompt` is not defined.

Run: `swift test --filter GeneratedCardDraftTests`

Expected: FAIL because `GeneratedCardDraft` and `GeneratedCardDraftMapper` are not defined.

- [ ] **Step 4: Add prompt builder**

Create `Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift`:

```swift
import Foundation

public enum FoundationModelCardPrompt {
    public static let maximumSectionCharacters = 7_500

    public static let instructions = """
    You generate study flashcards from private EPUB sections.
    Only use the supplied EPUB section. Do not add outside facts or world knowledge.
    Create one high-signal draft card when the section has enough substance.
    Use a basic question or a cloze sentence depending on what best fits the source.
    Paraphrase the source. Do not copy long passages or long headings verbatim.
    Keep the answer short, concrete, and useful for review.
    Do not create or change source anchors.
    Return useful tags, but avoid generic tags like book, section, flashcard, or study.
    """

    public static func prompt(
        for section: BookSection,
        maxCharacters: Int = maximumSectionCharacters
    ) -> String {
        let sourceExcerpt = excerpt(from: section.text, maxCharacters: maxCharacters)
        return """
        Generate a draft study card from this EPUB section.

        Source anchor: \(section.anchor.suffix)
        Heading: \(section.heading)
        Spine index: \(section.spineIndex)
        Block index: \(section.blockIndex)

        Do not create or change source anchors.
        Base the card only on this source excerpt:

        \(sourceExcerpt)
        """
    }

    public static func excerpt(from text: String, maxCharacters: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard maxCharacters > 0, trimmed.count > maxCharacters else {
            return trimmed
        }

        let limit = trimmed.index(trimmed.startIndex, offsetBy: maxCharacters)
        let prefix = String(trimmed[..<limit])
        if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
            return String(prefix[...sentenceEnd])
        }

        return prefix
    }
}
```

- [ ] **Step 5: Add draft value and mapper**

Create `Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift`:

```swift
import Foundation

public struct GeneratedCardDraft: Equatable, Sendable {
    public var frontText: String
    public var backText: String
    public var kind: CardKind
    public var tags: [String]

    public init(frontText: String, backText: String, kind: CardKind, tags: [String]) {
        self.frontText = frontText
        self.backText = backText
        self.kind = kind
        self.tags = tags
    }
}

public enum GeneratedCardDraftMapper {
    public static func deckCard(from draft: GeneratedCardDraft, section: BookSection) -> DeckCard? {
        let frontText = draft.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let backText = draft.backText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !frontText.isEmpty, !backText.isEmpty else {
            return nil
        }

        return DeckCard(
            sectionID: section.id,
            frontText: frontText,
            backText: backText,
            kind: draft.kind,
            tags: mergedTags(from: draft.tags),
            sourceAnchor: section.anchor
        )
    }

    private static func mergedTags(from generatedTags: [String]) -> [String] {
        var tags: [String] = []
        for tag in ["generated", "foundation-models"] + generatedTags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !tags.contains(normalized) else {
                continue
            }
            tags.append(normalized)
        }
        return tags
    }
}
```

- [ ] **Step 6: Run focused tests**

Run: `swift test --filter FoundationModelCardPromptTests`

Expected: PASS.

Run: `swift test --filter GeneratedCardDraftTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/EchoDeckBuilder/Services/FoundationModelCardPrompt.swift \
  Sources/EchoDeckBuilder/Services/GeneratedCardDraft.swift \
  Tests/EchoDeckBuilderTests/FoundationModelCardPromptTests.swift \
  Tests/EchoDeckBuilderTests/GeneratedCardDraftTests.swift
git commit -m "feat: add foundation model prompt mapping"
```

---

### Task 3: Foundation Models Availability And Generator

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`
- Create: `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`
- Modify: `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`
- Modify: `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`

**Interfaces:**
- Consumes: `FoundationModelCardPrompt`
- Consumes: `GeneratedCardDraftMapper`
- Consumes: `CardGenerationAvailability`
- Produces: `FoundationModelAvailability.current() -> CardGenerationAvailability`
- Produces: `FoundationModelCardGenerator.generateCards(for:) async throws -> [DeckCard]` on macOS 26+ with Foundation Models available
- Updates: `DefaultCardGeneratorResolver` to return a real Foundation Models generator when available

- [ ] **Step 1: Verify exact Foundation Models API spellings in the local SDK**

Run:

```bash
cat >/tmp/fm_schema_check.swift <<'SWIFT'
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
@Generable
struct GeneratedCardDraftCheck {
    @Guide(description: "The front of a flashcard. Use a question for basic cards or a cloze sentence for cloze cards.")
    var frontText: String

    @Guide(description: "The answer or explanation. Keep this short and grounded in the supplied section.")
    var backText: String

    @Guide(description: "Card kind", .anyOf(["basic", "cloze"]))
    var kind: String

    @Guide(description: "Short topical tags", .maximumCount(4))
    var tags: [String]
}

@available(macOS 26.0, *)
func check() async throws {
    let session = LanguageModelSession(instructions: "Generate cards.")
    let response = try await session.respond(
        to: "Create a card.",
        generating: GeneratedCardDraftCheck.self,
        options: GenerationOptions(sampling: .greedy, temperature: 0.2, maximumResponseTokens: 300)
    )
    _ = response.content.frontText
}
#endif
SWIFT
swiftc -target arm64-apple-macosx14.0 -typecheck /tmp/fm_schema_check.swift
```

Expected: command exits successfully with no diagnostics.

- [ ] **Step 2: Update resolver tests for fixture availability**

Append this test to `Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift`:

```swift
    func testDefaultResolverKeepsFixtureAvailable() async throws {
        let resolver = DefaultCardGeneratorResolver()
        let availability = resolver.availability(for: .fixture)

        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(availability.message, "Fixture generator ready")

        let cards = try await resolver.generator(for: .fixture).generateCards(for: [])
        XCTAssertEqual(cards, [])
    }
```

- [ ] **Step 3: Run the resolver test**

Run: `swift test --filter CardGenerationProviderTests/testDefaultResolverKeepsFixtureAvailable`

Expected: PASS before and after the resolver gains Foundation Models support.

- [ ] **Step 4: Add Foundation Models availability bridge**

Create `Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift`:

```swift
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum FoundationModelAvailability {
    public static func current() -> CardGenerationAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return currentOnSupportedOS()
        } else {
            return .unavailable("Foundation Models requires macOS 26+")
        }
        #else
        return .unavailable("Foundation Models is not available in this Xcode SDK")
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func currentOnSupportedOS() -> CardGenerationAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            guard model.supportsLocale() else {
                return .unavailable("Foundation Models does not support the current language")
            }
            return .available("Foundation Models ready")
        case .unavailable(.deviceNotEligible):
            return .unavailable("Foundation Models requires an Apple Intelligence-capable Mac")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in System Settings to use Foundation Models")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence is still preparing the language model")
        @unknown default:
            return .unavailable("Foundation Models is unavailable")
        }
    }
    #endif
}
```

- [ ] **Step 5: Add Foundation Models generator**

Create `Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift`:

```swift
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
public struct FoundationModelCardGenerator: CardGenerator {
    private let maximumSectionCharacters: Int

    public init(maximumSectionCharacters: Int = FoundationModelCardPrompt.maximumSectionCharacters) {
        self.maximumSectionCharacters = maximumSectionCharacters
    }

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        let availability = FoundationModelAvailability.current()
        guard availability.isAvailable else {
            throw CardGenerationError.unavailable(availability.message)
        }

        var cards: [DeckCard] = []
        cards.reserveCapacity(sections.count)

        for section in sections {
            try Task.checkCancellation()
            if let card = try await generateCard(for: section) {
                cards.append(card)
            }
        }

        return cards
    }

    private func generateCard(for section: BookSection) async throws -> DeckCard? {
        let prompt = FoundationModelCardPrompt.prompt(
            for: section,
            maxCharacters: maximumSectionCharacters
        )

        do {
            return try await requestCard(for: section, prompt: prompt, options: Self.defaultOptions)
        } catch let error as LanguageModelSession.GenerationError {
            return try await recover(from: error, section: section, prompt: prompt)
        }
    }

    private func recover(
        from error: LanguageModelSession.GenerationError,
        section: BookSection,
        prompt: String
    ) async throws -> DeckCard? {
        switch error {
        case .exceededContextWindowSize:
            let shorterPrompt = FoundationModelCardPrompt.prompt(
                for: section,
                maxCharacters: max(500, maximumSectionCharacters / 2)
            )
            return try await requestCardOrMapFailure(for: section, prompt: shorterPrompt, options: Self.retryOptions)
        case .decodingFailure:
            return try await requestCardOrMapFailure(for: section, prompt: prompt, options: Self.retryOptions)
        case .guardrailViolation, .refusal:
            return nil
        case .unsupportedLanguageOrLocale, .assetsUnavailable, .unsupportedGuide, .rateLimited, .concurrentRequests:
            throw Self.cardGenerationError(from: error)
        @unknown default:
            throw CardGenerationError.failed("Foundation Models generation failed")
        }
    }

    private func requestCardOrMapFailure(
        for section: BookSection,
        prompt: String,
        options: GenerationOptions
    ) async throws -> DeckCard? {
        do {
            return try await requestCard(for: section, prompt: prompt, options: options)
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.cardGenerationError(from: error)
        }
    }

    private func requestCard(
        for section: BookSection,
        prompt: String,
        options: GenerationOptions
    ) async throws -> DeckCard? {
        let session = LanguageModelSession(instructions: FoundationModelCardPrompt.instructions)
        let response = try await session.respond(
            to: prompt,
            generating: FoundationModelGeneratedCardDraft.self,
            options: options
        )
        return GeneratedCardDraftMapper.deckCard(from: response.content.cardDraft, section: section)
    }

    private static var defaultOptions: GenerationOptions {
        GenerationOptions(sampling: .greedy, temperature: 0.2, maximumResponseTokens: 320)
    }

    private static var retryOptions: GenerationOptions {
        GenerationOptions(sampling: .greedy, temperature: 0.0, maximumResponseTokens: 260)
    }

    private static func cardGenerationError(from error: LanguageModelSession.GenerationError) -> CardGenerationError {
        switch error {
        case .exceededContextWindowSize:
            return .failed("A source section is too large for Foundation Models")
        case .assetsUnavailable:
            return .unavailable("Apple Intelligence language model assets are unavailable")
        case .guardrailViolation, .refusal:
            return .failed("Foundation Models blocked the generated card for this section")
        case .unsupportedGuide:
            return .failed("The Foundation Models card schema is not supported")
        case .unsupportedLanguageOrLocale:
            return .unavailable("Foundation Models does not support the current language")
        case .decodingFailure:
            return .failed("Foundation Models could not produce a valid card draft")
        case .rateLimited:
            return .failed("Foundation Models is rate limited. Try again shortly.")
        case .concurrentRequests:
            return .failed("Foundation Models is already generating a response")
        @unknown default:
            return .failed("Foundation Models generation failed")
        }
    }
}

@available(macOS 26.0, *)
@Generable
private struct FoundationModelGeneratedCardDraft {
    @Guide(description: "The front of a flashcard. Use a question for basic cards or a cloze sentence for cloze cards.")
    var frontText: String

    @Guide(description: "The answer or explanation. Keep this short and grounded in the supplied section.")
    var backText: String

    @Guide(description: "Card kind", .anyOf(["basic", "cloze"]))
    var kind: String

    @Guide(description: "Short topical tags", .maximumCount(4))
    var tags: [String]

    var cardDraft: GeneratedCardDraft {
        GeneratedCardDraft(
            frontText: frontText,
            backText: backText,
            kind: CardKind(rawValue: kind) ?? .basic,
            tags: tags
        )
    }
}
#endif
```

- [ ] **Step 6: Wire the default resolver to Foundation Models**

In `Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift`, replace `DefaultCardGeneratorResolver` with:

```swift
public struct DefaultCardGeneratorResolver: CardGeneratorResolving {
    public init() {}

    public func availability(for provider: CardGenerationProvider) -> CardGenerationAvailability {
        switch provider {
        case .fixture:
            return .available("Fixture generator ready")
        case .foundationModels:
            return FoundationModelAvailability.current()
        }
    }

    public func generator(for provider: CardGenerationProvider) -> any CardGenerator {
        switch provider {
        case .fixture:
            return FixtureCardGenerator()
        case .foundationModels:
            let availability = availability(for: provider)
            guard availability.isAvailable else {
                return UnavailableCardGenerator(message: availability.message)
            }

            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                return FoundationModelCardGenerator()
            }
            #endif

            return UnavailableCardGenerator(message: availability.message)
        }
    }
}
```

- [ ] **Step 7: Build and run tests**

Run: `swift build`

Expected: PASS. The build proves `@Generable`, `@Guide(.anyOf(...))`, `@Guide(.maximumCount(...))`, and `LanguageModelSession.respond(...generating:)` typecheck in the package.

Run: `swift test --filter CardGenerationProviderTests`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/EchoDeckBuilder/Services/FoundationModelAvailability.swift \
  Sources/EchoDeckBuilder/Services/FoundationModelCardGenerator.swift \
  Sources/EchoDeckBuilder/Services/CardGeneratorResolver.swift \
  Tests/EchoDeckBuilderTests/CardGenerationProviderTests.swift
git commit -m "feat: add foundation models card generator"
```

---

### Task 4: Inspector Provider UI

**Files:**
- Modify: `Sources/EchoDeckBuilder/Views/InspectorView.swift`
- Modify: `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `LibraryStore.selectedGenerationProvider`
- Consumes: `LibraryStore.generationAvailability`
- Produces: Inspector provider picker and availability text

- [ ] **Step 1: Add a store test for provider switching status**

Append this test to `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift` before `private func makeFixture(...)`:

```swift
    func testChangingSelectedGenerationProviderUpdatesAvailability() throws {
        let fixture = try makeFixture()
        let store = LibraryStore(
            sections: [fixture.section],
            selectedGenerationProvider: .fixture,
            generatorResolver: UnavailableFoundationModelResolver()
        )

        XCTAssertEqual(store.generationAvailability.message, "Fixture generator ready")
        XCTAssertTrue(store.canGenerateCards)

        store.selectedGenerationProvider = .foundationModels

        XCTAssertEqual(store.generationAvailability.message, "Foundation Models requires macOS 26+")
        XCTAssertFalse(store.canGenerateCards)
    }
```

- [ ] **Step 2: Run the new store test**

Run: `swift test --filter LibraryStoreTests/testChangingSelectedGenerationProviderUpdatesAvailability`

Expected: PASS if Task 1 is complete.

- [ ] **Step 3: Update inspector UI**

Replace `Sources/EchoDeckBuilder/Views/InspectorView.swift` with:

```swift
import SwiftUI

struct InspectorView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        Form {
            Section("Deck") {
                TextField("Deck name", text: $store.deckName)
                TextField("Target media ID", text: $store.targetMediaID)
            }

            Section("Generation") {
                Picker("Provider", selection: $store.selectedGenerationProvider) {
                    ForEach(CardGenerationProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                LabeledContent("Availability") {
                    Text(store.generationAvailability.message)
                        .foregroundStyle(store.generationAvailability.isAvailable ? .secondary : .red)
                }
            }

            if let card = store.selectedCard {
                Section("Source") {
                    LabeledContent("Anchor", value: card.sourceAnchor.suffix)
                    LabeledContent("State", value: card.reviewState.rawValue.capitalized)
                }
            }

            Section("Status") {
                Text(store.statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 4: Build and run focused tests**

Run: `swift build`

Expected: PASS.

Run: `swift test --filter LibraryStoreTests/testChangingSelectedGenerationProviderUpdatesAvailability`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/EchoDeckBuilder/Views/InspectorView.swift \
  Tests/EchoDeckBuilderTests/LibraryStoreTests.swift
git commit -m "feat: show card generator provider in inspector"
```

---

### Task 5: Final Verification And Manual Test Checklist

**Files:**
- Create: `docs/foundation-models-manual-test.md`

**Interfaces:**
- Consumes: completed provider, prompt, generator, store, and inspector work
- Produces: manual Foundation Models verification checklist

- [ ] **Step 1: Add manual test checklist**

Create `docs/foundation-models-manual-test.md`:

```markdown
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
```

- [ ] **Step 2: Run full verification**

Run: `swift test`

Expected: PASS with all XCTest tests passing.

Run: `swift build`

Expected: PASS.

Run: `./script/build_and_run.sh --verify`

Expected: PASS and the app process launches.

- [ ] **Step 3: Inspect git diff**

Run: `git diff --check`

Expected: no output.

Run: `git status --short`

Expected: only the intended files from this task are modified or untracked.

- [ ] **Step 4: Commit**

```bash
git add docs/foundation-models-manual-test.md
git commit -m "docs: add foundation models manual test checklist"
```

---

## Self-Review Checklist

- Spec coverage:
  - Optional Foundation Models provider: Task 3.
  - Preserve macOS 14 package floor: Tasks 1 and 3 avoid `Package.swift` changes and gate Foundation Models.
  - Preserve fixture fallback: Tasks 1 and 3 keep `FixtureCardGenerator`.
  - Deterministic anchors: Task 2 maps `BookSection.anchor` directly to `DeckCard.sourceAnchor`.
  - Provider availability UI: Task 4.
  - Unit tests without Apple Intelligence: Tasks 1, 2, and 4.
  - Manual Apple Intelligence verification: Task 5.
- Type consistency:
  - Provider enum is always `CardGenerationProvider`.
  - Availability value is always `CardGenerationAvailability`.
  - Resolver protocol is always `CardGeneratorResolving`.
  - Pure draft value is always `GeneratedCardDraft`.
  - Foundation Models private generated type is always `FoundationModelGeneratedCardDraft`.
- Verification:
  - Run `swift test` after each task that changes behavior.
  - Run `swift build` after adding Foundation Models code and after UI wiring.
  - Run `git diff --check` before final handoff.
