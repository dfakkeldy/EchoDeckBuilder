import SwiftUI

struct ContentView: View {
    @Bindable var store: LibraryStore
    let importEPUB: () -> Void

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
                    importEPUB()
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
