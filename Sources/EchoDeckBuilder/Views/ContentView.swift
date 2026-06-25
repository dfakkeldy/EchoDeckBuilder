import SwiftUI

struct ContentView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            SectionListView(store: store)
        } detail: {
            CardReviewView(store: store)
        }
        .inspector(isPresented: $store.isInspectorPresented) {
            InspectorView(store: store)
                .inspectorColumnWidth(min: 260, ideal: 320, max: 380)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.requestImportPanel()
                } label: {
                    Label("Import EPUB", systemImage: "square.and.arrow.down")
                }

                Button {
                    store.generateCardsForSelectedBook()
                } label: {
                    Label("Generate Cards", systemImage: "sparkles")
                }
                .disabled(!store.canGenerateCards)

                Button {
                    store.requestEchoExportPanel()
                } label: {
                    Label("Export Echo Deck", systemImage: "square.and.arrow.up")
                }
                .disabled(!store.canExportEchoDeck)
            }
        }
    }
}
