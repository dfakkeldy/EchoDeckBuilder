import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct EchoDeckBuilderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LibraryStore()

    @MainActor
    private func chooseEPUB() {
        let panel = NSOpenPanel()
        if let epubType = UTType(filenameExtension: "epub") {
            if #available(macOS 15, *) {
                panel.allowedContentTypes = [.epub]
            } else {
                panel.allowedContentTypes = [epubType]
            }
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await library.importEPUB(at: url) }
        }
    }

    var body: some Scene {
        WindowGroup("EchoDeckBuilder", id: "main") {
            ContentView(store: library, importEPUB: chooseEPUB)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import EPUB...") {
                    chooseEPUB()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Export Echo Deck...") {
                    library.requestEchoExportPanel()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
