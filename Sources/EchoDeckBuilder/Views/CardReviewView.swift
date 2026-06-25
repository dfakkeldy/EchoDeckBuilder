import SwiftUI

struct CardReviewView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        Group {
            if let cardID = store.selectedCardID, let card = store.selectedCard {
                Form {
                    TextField(
                        "Front",
                        text: Binding(
                            get: { card.frontText },
                            set: { newValue in
                                store.update(cardID: cardID) { $0.frontText = newValue }
                            }
                        ),
                        axis: .vertical
                    )

                    TextField(
                        "Back",
                        text: Binding(
                            get: { card.backText },
                            set: { newValue in
                                store.update(cardID: cardID) { $0.backText = newValue }
                            }
                        ),
                        axis: .vertical
                    )

                    Picker(
                        "Kind",
                        selection: Binding(
                            get: { card.kind },
                            set: { newValue in
                                store.update(cardID: cardID) { $0.kind = newValue }
                            }
                        )
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
}
