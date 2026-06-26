import SwiftUI

struct CardReviewView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        Group {
            if let cardID = store.selectedCardID, store.card(id: cardID) != nil {
                Form {
                    TextField(
                        "Front",
                        text: textBinding(cardID: cardID, keyPath: \.frontText),
                        axis: .vertical
                    )

                    TextField(
                        "Back",
                        text: textBinding(cardID: cardID, keyPath: \.backText),
                        axis: .vertical
                    )

                    Picker(
                        "Kind",
                        selection: kindBinding(cardID: cardID)
                    ) {
                        ForEach(CardKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }

                    HStack {
                        Button {
                            store.accept(cardID: cardID)
                        } label: {
                            Label("Accept", systemImage: "checkmark.circle")
                        }

                        Button {
                            store.reject(cardID: cardID)
                        } label: {
                            Label("Reject", systemImage: "xmark.circle")
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
                .navigationTitle("Review")
            } else {
                ContentUnavailableView("No Card Selected", systemImage: "rectangle.stack")
            }
        }
    }

    private func textBinding(cardID: DeckCard.ID, keyPath: WritableKeyPath<DeckCard, String>) -> Binding<String> {
        Binding(
            get: { store.card(id: cardID)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                store.update(cardID: cardID) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func kindBinding(cardID: DeckCard.ID) -> Binding<CardKind> {
        Binding(
            get: { store.card(id: cardID)?.kind ?? .basic },
            set: { newValue in
                store.update(cardID: cardID) { $0.kind = newValue }
            }
        )
    }
}
