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
    @State private var library = LibraryStore(generatorResolver: DefaultCardGeneratorResolver())

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
            _ = url.startAccessingSecurityScopedResource()
            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                await library.importEPUB(at: url)
            }
        }
    }

    @MainActor
    private func chooseEchoDeckExport() {
        guard library.canExportEchoDeck else {
            library.requestEchoExportPanel()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(library.deckName).echo-deck.json"

        if panel.runModal() == .OK, let url = panel.url {
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                try library.echoDeckJSONData().write(to: url, options: .atomic)
                library.statusMessage = "Exported Echo deck JSON to \(url.lastPathComponent)"
            } catch {
                library.statusMessage = "Echo deck export failed: \(error.localizedDescription)"
            }
        }
    }

    var body: some Scene {
        WindowGroup("EchoDeckBuilder", id: "main") {
            ContentView(store: library, importEPUB: chooseEPUB, exportEchoDeck: chooseEchoDeckExport)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import EPUB...") {
                    chooseEPUB()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Export Echo Deck...") {
                    chooseEchoDeckExport()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
