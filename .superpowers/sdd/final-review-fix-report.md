What changed
- Rewrote README product-direction/privacy copy so Builder is the proof harness and Echo is the long-term home for native deck creation, review, target media selection, persistence, and study context.
- Changed `LibraryStore.generationAvailability` from a computed resolver call to cached state with async refresh on provider changes, while keeping resolver-side unavailable-generator protection intact.
- Updated `InspectorView` to bind cached availability once per body and added focused `LibraryStoreTests` coverage for cached reads and async refresh.

Commands/results
- `swift test --filter LibraryStoreTests` -> passed
- `swift test --filter CardGenerationProviderTests` -> passed
- `swift build` -> passed

Files changed
- `README.md`
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- `Sources/EchoDeckBuilder/Views/InspectorView.swift`
- `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`

Concerns
- The cached availability now briefly shows a checking message after provider changes; that is intentional to avoid synchronous CLI lookup on SwiftUI redraws.
