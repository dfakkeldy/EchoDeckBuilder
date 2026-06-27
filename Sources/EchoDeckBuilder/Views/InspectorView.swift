import SwiftUI

struct InspectorView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        let availability = store.generationAvailability

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
                    Text(availability.message)
                        .foregroundStyle(
                            availability.isAvailable
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(.red)
                        )
                }

                if let disclosure = store.selectedGenerationProvider.disclosureMessage {
                    Text(disclosure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Model", text: generationBinding(\.model))

                Stepper(
                    value: generationBinding(\.batchSize),
                    in: 1...30
                ) {
                    LabeledContent("Batch size", value: "\(store.generationSettings.batchSize)")
                }

                Stepper(
                    value: generationBinding(\.targetCardsPerBatch),
                    in: 1...30
                ) {
                    LabeledContent("Cards per batch", value: "\(store.generationSettings.targetCardsPerBatch)")
                }

                Picker("Image mode", selection: generationBinding(\.imageMode)) {
                    ForEach(ImageGenerationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            if let latestBookBrief = store.latestBookBrief {
                Section("Latest Brief") {
                    Text(latestBookBrief.summary)
                        .foregroundStyle(.secondary)
                }
            }

            if !store.generationWarnings.isEmpty {
                Section("Generation Warnings") {
                    ForEach(store.generationWarnings, id: \.self) { warning in
                        Label {
                            Text(warning.message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.yellow)
                        }
                    }
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

    private func generationBinding<Value>(_ keyPath: WritableKeyPath<GenerationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.generationSettings[keyPath: keyPath] },
            set: { newValue in
                store.generationSettings[keyPath: keyPath] = newValue
            }
        )
    }
}
