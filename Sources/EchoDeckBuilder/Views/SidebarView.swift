import SwiftUI

struct SidebarView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        List(selection: $store.selectedSectionID) {
            Section("Sections") {
                ForEach(store.sections) { section in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.heading)
                                .lineLimit(1)
                            Text(section.anchor.suffix)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                    .tag(section.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Books")
    }
}
