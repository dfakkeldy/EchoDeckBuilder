import AppKit
import SwiftUI

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

    var body: some Scene {
        WindowGroup("EchoDeckBuilder", id: "main") {
            ContentView(store: library)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import EPUB...") {
                    library.requestImportPanel()
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
