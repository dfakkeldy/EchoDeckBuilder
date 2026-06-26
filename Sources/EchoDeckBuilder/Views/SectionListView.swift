import SwiftUI

struct SectionListView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        List(selection: cardSelection) {
            if let section = store.selectedSection {
                Section(section.heading) {
                    ForEach(store.cards.filter { $0.sectionID == section.id }) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.frontText)
                                .lineLimit(2)
                            Text(card.sourceAnchor.suffix)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(card.id)
                    }
                }
            } else {
                Text("Import an EPUB to begin")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cards")
    }

    private var cardSelection: Binding<DeckCard.ID?> {
        Binding(
            get: { store.selectedCardID },
            set: { store.selectCard($0) }
        )
    }
}
