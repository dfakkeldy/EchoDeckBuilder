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
                        .foregroundStyle(
                            store.generationAvailability.isAvailable
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(.red)
                        )
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
