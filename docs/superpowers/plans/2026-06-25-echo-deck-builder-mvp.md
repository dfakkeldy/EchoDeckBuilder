# EchoDeckBuilder MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable macOS MVP of EchoDeckBuilder: import an EPUB locally, extract stable source-anchored sections, generate deterministic reviewable card drafts, and export Echo deck JSON vNext using per-card `sourceAnchor`.

**Architecture:** Use a package-first SwiftPM macOS app with small SwiftUI views, tested domain models, pure extraction/export services, and one observable app store. The app treats Echo import vNext as already available: EchoDeckBuilder exports portable block suffixes, and Echo resolves those suffixes into local `epub_block.id` values.

**Tech Stack:** SwiftPM, Swift 6, SwiftUI for macOS 14+, XCTest, Foundation `XMLParser`, `/usr/bin/unzip` for EPUB archive expansion, no third-party packages.

## Global Constraints

- Echo-ready cards use canonical portable source anchors shaped `s<i>-b<j>`.
- Echo deck JSON vNext exports per-card `sourceAnchor`; it does not export full foreign `epub_block.id` values as canonical anchors.
- Echo import vNext is assumed complete: Echo resolves `sourceAnchor` against `targetMediaID`, validates `id` and `audiobook_id`, stores `flashcard.source_block_id`, and treats unresolved anchors as non-fatal warnings.
- EPUB extraction happens locally.
- The user explicitly chooses any AI provider; this MVP uses a deterministic fixture generator and sends no book content to a network service.
- Generated cards paraphrase source material and avoid long source quotations.
- Private copyrighted material must never be uploaded, shared, or bundled into examples.
- Avoid third-party dependencies until the first pipeline works with standard library tools and Echo's import contract.

---

## Scope Check

The README describes multiple independent subsystems. This plan covers the first buildable MVP only:

- Included: SwiftPM macOS app scaffold, local EPUB-to-section extraction, stable `s<i>-b<j>` anchors, deterministic draft card generation, review/edit state, Echo JSON vNext export, Anki TSV export, diagnostics, and a runnable SwiftUI shell.
- Separate plans should cover: live AI provider integrations, APKG archive generation, optional Echo database matching, rich dedupe heuristics, and Echo repo importer implementation.

## File Structure

- `Package.swift`: SwiftPM products and targets.
- `.codex/environments/environment.toml`: Codex app Run action.
- `script/build_and_run.sh`: single build, bundle, launch, log, and verify entrypoint for the macOS app.
- `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`: `@main` app, foreground activation delegate, scene setup.
- `Sources/EchoDeckBuilder/Views/ContentView.swift`: root split layout composition.
- `Sources/EchoDeckBuilder/Views/SidebarView.swift`: imported books and generated decks list.
- `Sources/EchoDeckBuilder/Views/SectionListView.swift`: section rows for selected book.
- `Sources/EchoDeckBuilder/Views/CardReviewView.swift`: card review/editor surface.
- `Sources/EchoDeckBuilder/Views/InspectorView.swift`: source anchor, tags, export status, and settings.
- `Sources/EchoDeckBuilder/Models/SourceAnchor.swift`: canonical anchor parsing and legacy full-ID suffix stripping.
- `Sources/EchoDeckBuilder/Models/BookSection.swift`: EPUB section/block model.
- `Sources/EchoDeckBuilder/Models/DeckCard.swift`: reviewable card draft model.
- `Sources/EchoDeckBuilder/Models/EchoDeckDocument.swift`: JSON export schema.
- `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`: app-owned observable state and commands.
- `Sources/EchoDeckBuilder/Services/EPUBArchiveExtractor.swift`: expands `.epub` into a temporary directory with `/usr/bin/unzip`.
- `Sources/EchoDeckBuilder/Services/EPUBManifestParser.swift`: reads container, OPF manifest, and spine order.
- `Sources/EchoDeckBuilder/Services/XHTMLBlockExtractor.swift`: extracts heading/text blocks and assigns anchors.
- `Sources/EchoDeckBuilder/Services/FixtureCardGenerator.swift`: deterministic local card drafts for MVP.
- `Sources/EchoDeckBuilder/Services/EchoDeckJSONExporter.swift`: Echo JSON vNext export.
- `Sources/EchoDeckBuilder/Services/AnkiTSVExporter.swift`: simple Anki-compatible TSV export.
- `Sources/EchoDeckBuilder/Services/DiagnosticsExporter.swift`: section/card/anchor diagnostics report.
- `Tests/EchoDeckBuilderTests/*.swift`: model, extraction, generation, and export tests.

---

### Task 1: SwiftPM macOS App Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`
- Create: `Sources/EchoDeckBuilder/Views/ContentView.swift`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

**Interfaces:**
- Produces: executable product `EchoDeckBuilder`
- Produces: app entrypoint `EchoDeckBuilderApp`
- Produces: minimal root view `ContentView`

- [ ] **Step 1: Write the package manifest**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EchoDeckBuilder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EchoDeckBuilder", targets: ["EchoDeckBuilder"])
    ],
    targets: [
        .executableTarget(
            name: "EchoDeckBuilder",
            path: "Sources/EchoDeckBuilder"
        ),
        .testTarget(
            name: "EchoDeckBuilderTests",
            dependencies: ["EchoDeckBuilder"],
            path: "Tests/EchoDeckBuilderTests"
        )
    ]
)
```

- [ ] **Step 2: Write the app entrypoint**

```swift
// Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift
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

    var body: some Scene {
        WindowGroup("EchoDeckBuilder", id: "main") {
            ContentView()
                .frame(minWidth: 1040, minHeight: 680)
        }
    }
}
```

- [ ] **Step 3: Write the minimal root view**

```swift
// Sources/EchoDeckBuilder/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("EchoDeckBuilder")
                .font(.title)

            Text("Import an EPUB, review source-anchored cards, and export Echo deck JSON vNext.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding()
    }
}
```

- [ ] **Step 4: Write the build and run script**

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="EchoDeckBuilder"
BUNDLE_ID="com.dfakkeldy.EchoDeckBuilder"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

Run: `chmod +x script/build_and_run.sh`

- [ ] **Step 5: Write the Codex Run action**

```toml
# .codex/environments/environment.toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "EchoDeckBuilder"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 6: Build the empty app**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/EchoDeckBuilder script .codex
git commit -m "chore: scaffold macOS deck builder app"
```

---

### Task 2: Domain Models And Anchor Parsing

**Files:**
- Create: `Sources/EchoDeckBuilder/Models/SourceAnchor.swift`
- Create: `Sources/EchoDeckBuilder/Models/BookSection.swift`
- Create: `Sources/EchoDeckBuilder/Models/DeckCard.swift`
- Test: `Tests/EchoDeckBuilderTests/SourceAnchorTests.swift`

**Interfaces:**
- Produces: `SourceAnchor(suffix:)`, `SourceAnchor.parse(_:)`, `SourceAnchor.fullEchoBlockID(targetMediaID:)`
- Produces: `BookSection(id:spineIndex:blockIndex:heading:text:anchor:)`
- Produces: `DeckCard`

- [ ] **Step 1: Write failing anchor tests**

```swift
// Tests/EchoDeckBuilderTests/SourceAnchorTests.swift
import XCTest
@testable import EchoDeckBuilder

final class SourceAnchorTests: XCTestCase {
    func testCanonicalSuffixIsAccepted() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("s4-b12"))
        XCTAssertEqual(anchor.suffix, "s4-b12")
    }

    func testLegacyFullBlockIDStripsToPortableSuffix() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("epub-old-book-id-s4-b12"))
        XCTAssertEqual(anchor.suffix, "s4-b12")
    }

    func testMalformedAnchorIsRejected() {
        XCTAssertNil(SourceAnchor.parse("chapter-4-block-12"))
        XCTAssertNil(SourceAnchor.parse("s4"))
        XCTAssertNil(SourceAnchor.parse("b12"))
    }

    func testLocalFullIDUsesTargetMediaID() throws {
        let anchor = try XCTUnwrap(SourceAnchor.parse("s4-b12"))
        XCTAssertEqual(anchor.fullEchoBlockID(targetMediaID: "book-123"), "epub-book-123-s4-b12")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SourceAnchorTests`

Expected: FAIL because `SourceAnchor` is not defined.

- [ ] **Step 3: Implement source anchors**

```swift
// Sources/EchoDeckBuilder/Models/SourceAnchor.swift
import Foundation

public struct SourceAnchor: Codable, Hashable, Identifiable, Sendable {
    public var id: String { suffix }
    public let suffix: String

    public init?(suffix: String) {
        guard Self.isCanonicalSuffix(suffix) else { return nil }
        self.suffix = suffix
    }

    public static func parse(_ rawValue: String?) -> SourceAnchor? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCanonicalSuffix(trimmed) {
            return SourceAnchor(suffix: trimmed)
        }
        guard let range = trimmed.range(of: #"s[0-9]+-b[0-9]+$"#, options: .regularExpression) else {
            return nil
        }
        return SourceAnchor(suffix: String(trimmed[range]))
    }

    public func fullEchoBlockID(targetMediaID: String) -> String {
        "epub-\(targetMediaID)-\(suffix)"
    }

    private static func isCanonicalSuffix(_ value: String) -> Bool {
        value.range(of: #"^s[0-9]+-b[0-9]+$"#, options: .regularExpression) != nil
    }
}
```

- [ ] **Step 4: Implement book sections**

```swift
// Sources/EchoDeckBuilder/Models/BookSection.swift
import Foundation

public struct BookSection: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var spineIndex: Int
    public var blockIndex: Int
    public var heading: String
    public var text: String
    public var anchor: SourceAnchor

    public init(
        id: UUID = UUID(),
        spineIndex: Int,
        blockIndex: Int,
        heading: String,
        text: String,
        anchor: SourceAnchor
    ) {
        self.id = id
        self.spineIndex = spineIndex
        self.blockIndex = blockIndex
        self.heading = heading
        self.text = text
        self.anchor = anchor
    }
}
```

- [ ] **Step 5: Implement deck cards**

```swift
// Sources/EchoDeckBuilder/Models/DeckCard.swift
import Foundation

public enum CardKind: String, Codable, CaseIterable, Sendable {
    case basic
    case cloze
}

public enum CardReviewState: String, Codable, CaseIterable, Sendable {
    case draft
    case accepted
    case rejected
}

public struct DeckCard: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sectionID: BookSection.ID
    public var frontText: String
    public var backText: String
    public var kind: CardKind
    public var tags: [String]
    public var sourceAnchor: SourceAnchor
    public var reviewState: CardReviewState

    public init(
        id: UUID = UUID(),
        sectionID: BookSection.ID,
        frontText: String,
        backText: String,
        kind: CardKind,
        tags: [String] = [],
        sourceAnchor: SourceAnchor,
        reviewState: CardReviewState = .draft
    ) {
        self.id = id
        self.sectionID = sectionID
        self.frontText = frontText
        self.backText = backText
        self.kind = kind
        self.tags = tags
        self.sourceAnchor = sourceAnchor
        self.reviewState = reviewState
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter SourceAnchorTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/EchoDeckBuilder/Models Tests/EchoDeckBuilderTests/SourceAnchorTests.swift
git commit -m "feat: add source anchored deck models"
```

---

### Task 3: EPUB Extraction Pipeline

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/EPUBArchiveExtractor.swift`
- Create: `Sources/EchoDeckBuilder/Services/EPUBManifestParser.swift`
- Create: `Sources/EchoDeckBuilder/Services/XHTMLBlockExtractor.swift`
- Test: `Tests/EchoDeckBuilderTests/XHTMLBlockExtractorTests.swift`
- Test: `Tests/EchoDeckBuilderTests/EPUBManifestParserTests.swift`

**Interfaces:**
- Consumes: `BookSection`, `SourceAnchor`
- Produces: `EPUBArchiveExtractor.extract(epubURL:) async throws -> URL`
- Produces: `EPUBManifestParser.spineItems(in:) throws -> [EPUBSpineItem]`
- Produces: `XHTMLBlockExtractor.sections(from:spineIndex:) throws -> [BookSection]`

- [ ] **Step 1: Write failing XHTML extraction tests**

```swift
// Tests/EchoDeckBuilderTests/XHTMLBlockExtractorTests.swift
import XCTest
@testable import EchoDeckBuilder

final class XHTMLBlockExtractorTests: XCTestCase {
    func testExtractsParagraphBlocksWithPortableAnchors() throws {
        let xhtml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1>Chapter 4</h1>
            <p>Constraints shape behavior.</p>
            <p>Good prompts preserve useful context.</p>
          </body>
        </html>
        """

        let sections = try XHTMLBlockExtractor().sections(from: Data(xhtml.utf8), spineIndex: 4)

        XCTAssertEqual(sections.map(\.heading), ["Chapter 4", "Chapter 4"])
        XCTAssertEqual(sections.map(\.text), ["Constraints shape behavior.", "Good prompts preserve useful context."])
        XCTAssertEqual(sections.map(\.anchor.suffix), ["s4-b1", "s4-b2"])
    }
}
```

- [ ] **Step 2: Run the XHTML tests to verify they fail**

Run: `swift test --filter XHTMLBlockExtractorTests`

Expected: FAIL because `XHTMLBlockExtractor` is not defined.

- [ ] **Step 3: Implement XHTML block extraction**

```swift
// Sources/EchoDeckBuilder/Services/XHTMLBlockExtractor.swift
import Foundation

public final class XHTMLBlockExtractor: NSObject, XMLParserDelegate {
    private var spineIndex = 0
    private var currentElement = ""
    private var currentHeading = "Untitled Section"
    private var currentText = ""
    private var pendingBlocks: [(heading: String, text: String)] = []

    public func sections(from data: Data, spineIndex: Int) throws -> [BookSection] {
        self.spineIndex = spineIndex
        currentElement = ""
        currentHeading = "Untitled Section"
        currentText = ""
        pendingBlocks = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw EPUBExtractionError.xhtmlParseFailed(parser.parserError?.localizedDescription ?? "Unknown XML parse error")
        }

        return pendingBlocks.enumerated().compactMap { offset, block in
            let blockIndex = offset + 1
            guard let anchor = SourceAnchor(suffix: "s\(spineIndex)-b\(blockIndex)") else {
                return nil
            }
            return BookSection(
                spineIndex: spineIndex,
                blockIndex: blockIndex,
                heading: block.heading,
                text: block.text,
                anchor: anchor
            )
        }
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        if Self.blockElements.contains(currentElement) || Self.headingElements.contains(currentElement) {
            currentText = ""
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard Self.blockElements.contains(currentElement) || Self.headingElements.contains(currentElement) else {
            return
        }
        currentText += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = elementName.lowercased()
        let normalized = currentText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.headingElements.contains(element), !normalized.isEmpty {
            currentHeading = normalized
        } else if Self.blockElements.contains(element), !normalized.isEmpty {
            pendingBlocks.append((heading: currentHeading, text: normalized))
        }

        currentText = ""
        currentElement = ""
    }

    private static let headingElements: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
    private static let blockElements: Set<String> = ["p", "blockquote", "li"]
}

public enum EPUBExtractionError: Error, Equatable {
    case unzipFailed(String)
    case containerMissingRootfile
    case packageMissingSpine
    case manifestItemMissing(String)
    case xhtmlParseFailed(String)
}
```

- [ ] **Step 4: Write failing OPF spine parser tests**

```swift
// Tests/EchoDeckBuilderTests/EPUBManifestParserTests.swift
import XCTest
@testable import EchoDeckBuilder

final class EPUBManifestParserTests: XCTestCase {
    func testReadsSpineItemsInOrder() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf">
          <manifest>
            <item id="chap1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="chap2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chap1"/>
            <itemref idref="chap2"/>
          </spine>
        </package>
        """

        let items = try EPUBManifestParser().spineItems(fromPackageData: Data(opf.utf8), packageDirectory: URL(fileURLWithPath: "/tmp/book/OEBPS"))

        XCTAssertEqual(items.map(\.spineIndex), [1, 2])
        XCTAssertEqual(items.map(\.href), ["Text/chapter1.xhtml", "Text/chapter2.xhtml"])
    }
}
```

- [ ] **Step 5: Implement OPF spine parsing**

```swift
// Sources/EchoDeckBuilder/Services/EPUBManifestParser.swift
import Foundation

public struct EPUBSpineItem: Hashable, Sendable {
    public let spineIndex: Int
    public let href: String
    public let fileURL: URL
}

public final class EPUBManifestParser: NSObject, XMLParserDelegate {
    private var manifest: [String: String] = [:]
    private var spineIDRefs: [String] = []

    public func spineItems(fromPackageData data: Data, packageDirectory: URL) throws -> [EPUBSpineItem] {
        manifest = [:]
        spineIDRefs = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw EPUBExtractionError.packageMissingSpine
        }

        guard !spineIDRefs.isEmpty else {
            throw EPUBExtractionError.packageMissingSpine
        }

        return try spineIDRefs.enumerated().map { offset, idref in
            guard let href = manifest[idref] else {
                throw EPUBExtractionError.manifestItemMissing(idref)
            }
            return EPUBSpineItem(
                spineIndex: offset + 1,
                href: href,
                fileURL: packageDirectory.appendingPathComponent(href)
            )
        }
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName.lowercased() {
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = href
            }
        case "itemref":
            if let idref = attributeDict["idref"] {
                spineIDRefs.append(idref)
            }
        default:
            break
        }
    }
}
```

- [ ] **Step 6: Implement EPUB archive expansion**

```swift
// Sources/EchoDeckBuilder/Services/EPUBArchiveExtractor.swift
import Foundation

public struct EPUBArchiveExtractor: Sendable {
    public init() {}

    public func extract(epubURL: URL) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilder")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", epubURL.path, "-d", destination.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "unzip exited with \(process.terminationStatus)"
            throw EPUBExtractionError.unzipFailed(message)
        }

        return destination
    }
}
```

- [ ] **Step 7: Run extraction tests**

Run: `swift test --filter XHTMLBlockExtractorTests && swift test --filter EPUBManifestParserTests`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/EchoDeckBuilder/Services Tests/EchoDeckBuilderTests/XHTMLBlockExtractorTests.swift Tests/EchoDeckBuilderTests/EPUBManifestParserTests.swift
git commit -m "feat: extract epub sections with source anchors"
```

---

### Task 4: Deterministic Card Generation

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/FixtureCardGenerator.swift`
- Test: `Tests/EchoDeckBuilderTests/FixtureCardGeneratorTests.swift`

**Interfaces:**
- Consumes: `[BookSection]`
- Produces: `CardGenerator.generateCards(for:) async throws -> [DeckCard]`

- [ ] **Step 1: Write failing generator tests**

```swift
// Tests/EchoDeckBuilderTests/FixtureCardGeneratorTests.swift
import XCTest
@testable import EchoDeckBuilder

final class FixtureCardGeneratorTests: XCTestCase {
    func testGeneratorCreatesOneDraftCardPerSectionAndPreservesAnchor() async throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s2-b3"))
        let section = BookSection(
            spineIndex: 2,
            blockIndex: 3,
            heading: "Prompts",
            text: "Good prompts preserve useful context for the model.",
            anchor: anchor
        )

        let cards = try await FixtureCardGenerator().generateCards(for: [section])

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sectionID, section.id)
        XCTAssertEqual(cards[0].sourceAnchor.suffix, "s2-b3")
        XCTAssertEqual(cards[0].reviewState, .draft)
        XCTAssertFalse(cards[0].frontText.isEmpty)
        XCTAssertFalse(cards[0].backText.isEmpty)
    }
}
```

- [ ] **Step 2: Run the generator test to verify it fails**

Run: `swift test --filter FixtureCardGeneratorTests`

Expected: FAIL because `FixtureCardGenerator` is not defined.

- [ ] **Step 3: Implement deterministic generation**

```swift
// Sources/EchoDeckBuilder/Services/FixtureCardGenerator.swift
import Foundation

public protocol CardGenerator: Sendable {
    func generateCards(for sections: [BookSection]) async throws -> [DeckCard]
}

public struct FixtureCardGenerator: CardGenerator {
    public init() {}

    public func generateCards(for sections: [BookSection]) async throws -> [DeckCard] {
        sections.map { section in
            let concept = section.heading == "Untitled Section" ? "this section" : section.heading
            let summary = section.text.split(separator: ".").first.map(String.init) ?? section.text
            return DeckCard(
                sectionID: section.id,
                frontText: "What is the key idea in \(concept)?",
                backText: summary,
                kind: .basic,
                tags: ["generated", "fixture"],
                sourceAnchor: section.anchor
            )
        }
    }
}
```

- [ ] **Step 4: Run the generator tests**

Run: `swift test --filter FixtureCardGeneratorTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/EchoDeckBuilder/Services/FixtureCardGenerator.swift Tests/EchoDeckBuilderTests/FixtureCardGeneratorTests.swift
git commit -m "feat: generate deterministic draft cards"
```

---

### Task 5: Echo Deck JSON vNext Export

**Files:**
- Create: `Sources/EchoDeckBuilder/Models/EchoDeckDocument.swift`
- Create: `Sources/EchoDeckBuilder/Services/EchoDeckJSONExporter.swift`
- Test: `Tests/EchoDeckBuilderTests/EchoDeckJSONExporterTests.swift`

**Interfaces:**
- Consumes: `[DeckCard]`
- Produces: `EchoDeckJSONExporter.export(deckName:targetMediaID:cards:) throws -> Data`

- [ ] **Step 1: Write failing export tests**

```swift
// Tests/EchoDeckBuilderTests/EchoDeckJSONExporterTests.swift
import XCTest
@testable import EchoDeckBuilder

final class EchoDeckJSONExporterTests: XCTestCase {
    func testExportsAcceptedCardsWithSourceAnchor() throws {
        let sectionID = UUID()
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s4-b12"))
        let card = DeckCard(
            sectionID: sectionID,
            frontText: "What does the chapter argue?",
            backText: "Constraints shape behavior.",
            kind: .basic,
            tags: ["chapter-4"],
            sourceAnchor: anchor,
            reviewState: .accepted
        )

        let data = try EchoDeckJSONExporter().export(
            deckName: "Chapter 4 Review",
            targetMediaID: "file:///Books/Example",
            cards: [card]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])

        XCTAssertEqual(object["deckName"] as? String, "Chapter 4 Review")
        XCTAssertEqual(object["targetMediaID"] as? String, "file:///Books/Example")
        XCTAssertEqual(cards.first?["sourceAnchor"] as? String, "s4-b12")
        XCTAssertNil(cards.first?["source"])
        XCTAssertNil(cards.first?["echoBlockID"])
    }

    func testRejectedCardsAreNotExported() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let rejected = DeckCard(
            sectionID: UUID(),
            frontText: "Rejected?",
            backText: "No export.",
            kind: .basic,
            sourceAnchor: anchor,
            reviewState: .rejected
        )

        let data = try EchoDeckJSONExporter().export(deckName: "Deck", targetMediaID: "book", cards: [rejected])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
        XCTAssertEqual(cards.count, 0)
    }
}
```

- [ ] **Step 2: Run export tests to verify they fail**

Run: `swift test --filter EchoDeckJSONExporterTests`

Expected: FAIL because `EchoDeckJSONExporter` is not defined.

- [ ] **Step 3: Implement export schema**

```swift
// Sources/EchoDeckBuilder/Models/EchoDeckDocument.swift
import Foundation

public struct EchoDeckDocument: Codable, Sendable {
    public var deckName: String
    public var targetMediaID: String
    public var cards: [EchoDeckCardDocument]
}

public struct EchoDeckCardDocument: Codable, Sendable {
    public var frontText: String
    public var backText: String
    public var startTime: Double
    public var endTime: Double
    public var triggerTiming: String
    public var sourceAnchor: String
}
```

- [ ] **Step 4: Implement JSON export**

```swift
// Sources/EchoDeckBuilder/Services/EchoDeckJSONExporter.swift
import Foundation

public struct EchoDeckJSONExporter: Sendable {
    public init() {}

    public func export(deckName: String, targetMediaID: String, cards: [DeckCard]) throws -> Data {
        let exportCards = cards
            .filter { $0.reviewState == .accepted }
            .map { card in
                EchoDeckCardDocument(
                    frontText: card.frontText,
                    backText: card.backText,
                    startTime: 0,
                    endTime: 0,
                    triggerTiming: "manualOnly",
                    sourceAnchor: card.sourceAnchor.suffix
                )
            }

        let document = EchoDeckDocument(deckName: deckName, targetMediaID: targetMediaID, cards: exportCards)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }
}
```

- [ ] **Step 5: Run export tests**

Run: `swift test --filter EchoDeckJSONExporterTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/EchoDeckBuilder/Models/EchoDeckDocument.swift Sources/EchoDeckBuilder/Services/EchoDeckJSONExporter.swift Tests/EchoDeckBuilderTests/EchoDeckJSONExporterTests.swift
git commit -m "feat: export echo deck json vnext"
```

---

### Task 6: TSV And Diagnostics Export

**Files:**
- Create: `Sources/EchoDeckBuilder/Services/AnkiTSVExporter.swift`
- Create: `Sources/EchoDeckBuilder/Services/DiagnosticsExporter.swift`
- Test: `Tests/EchoDeckBuilderTests/AnkiTSVExporterTests.swift`
- Test: `Tests/EchoDeckBuilderTests/DiagnosticsExporterTests.swift`

**Interfaces:**
- Consumes: `[DeckCard]`
- Produces: `AnkiTSVExporter.export(cards:) -> String`
- Produces: `DiagnosticsExporter.export(sections:cards:) -> String`

- [ ] **Step 1: Write failing TSV tests**

```swift
// Tests/EchoDeckBuilderTests/AnkiTSVExporterTests.swift
import XCTest
@testable import EchoDeckBuilder

final class AnkiTSVExporterTests: XCTestCase {
    func testExportsAcceptedCardsAsTabSeparatedRows() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b2"))
        let card = DeckCard(
            sectionID: UUID(),
            frontText: "Front text",
            backText: "Back text",
            kind: .basic,
            tags: ["tag one", "tag-two"],
            sourceAnchor: anchor,
            reviewState: .accepted
        )

        let output = AnkiTSVExporter().export(cards: [card])

        XCTAssertEqual(output, "Front text\tBack text\ttag_one tag-two\ts1-b2\n")
    }
}
```

- [ ] **Step 2: Implement TSV export**

```swift
// Sources/EchoDeckBuilder/Services/AnkiTSVExporter.swift
import Foundation

public struct AnkiTSVExporter: Sendable {
    public init() {}

    public func export(cards: [DeckCard]) -> String {
        cards
            .filter { $0.reviewState == .accepted }
            .map { card in
                [
                    sanitize(card.frontText),
                    sanitize(card.backText),
                    card.tags.map(normalizeTag).joined(separator: " "),
                    card.sourceAnchor.suffix
                ].joined(separator: "\t")
            }
            .joined(separator: "\n") + "\n"
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
    }
}
```

- [ ] **Step 3: Write failing diagnostics tests**

```swift
// Tests/EchoDeckBuilderTests/DiagnosticsExporterTests.swift
import XCTest
@testable import EchoDeckBuilder

final class DiagnosticsExporterTests: XCTestCase {
    func testDiagnosticsIncludesCountsAndAnchors() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(spineIndex: 1, blockIndex: 1, heading: "Intro", text: "Text", anchor: anchor)
        let card = DeckCard(sectionID: section.id, frontText: "Front", backText: "Back", kind: .basic, sourceAnchor: anchor, reviewState: .accepted)

        let report = DiagnosticsExporter().export(sections: [section], cards: [card])

        XCTAssertTrue(report.contains("Sections: 1"))
        XCTAssertTrue(report.contains("Cards: 1"))
        XCTAssertTrue(report.contains("Accepted: 1"))
        XCTAssertTrue(report.contains("s1-b1"))
    }
}
```

- [ ] **Step 4: Implement diagnostics export**

```swift
// Sources/EchoDeckBuilder/Services/DiagnosticsExporter.swift
import Foundation

public struct DiagnosticsExporter: Sendable {
    public init() {}

    public func export(sections: [BookSection], cards: [DeckCard]) -> String {
        let accepted = cards.filter { $0.reviewState == .accepted }.count
        let rejected = cards.filter { $0.reviewState == .rejected }.count
        let draft = cards.filter { $0.reviewState == .draft }.count
        let anchors = sections.map { "\($0.anchor.suffix) \($0.heading)" }.joined(separator: "\n")

        return """
        EchoDeckBuilder Diagnostics
        Sections: \(sections.count)
        Cards: \(cards.count)
        Accepted: \(accepted)
        Draft: \(draft)
        Rejected: \(rejected)

        Anchors:
        \(anchors)
        """
    }
}
```

- [ ] **Step 5: Run export tests**

Run: `swift test --filter AnkiTSVExporterTests && swift test --filter DiagnosticsExporterTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/EchoDeckBuilder/Services/AnkiTSVExporter.swift Sources/EchoDeckBuilder/Services/DiagnosticsExporter.swift Tests/EchoDeckBuilderTests/AnkiTSVExporterTests.swift Tests/EchoDeckBuilderTests/DiagnosticsExporterTests.swift
git commit -m "feat: export anki tsv and diagnostics"
```

---

### Task 7: Library Store And SwiftUI Review Shell

**Files:**
- Modify: `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`
- Modify: `Sources/EchoDeckBuilder/Views/ContentView.swift`
- Create: `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- Create: `Sources/EchoDeckBuilder/Views/SidebarView.swift`
- Create: `Sources/EchoDeckBuilder/Views/SectionListView.swift`
- Create: `Sources/EchoDeckBuilder/Views/CardReviewView.swift`
- Create: `Sources/EchoDeckBuilder/Views/InspectorView.swift`
- Test: `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `BookSection`, `DeckCard`, `FixtureCardGenerator`, exporters
- Produces: `@Observable final class LibraryStore`
- Produces: sidebar-detail-inspector UI with import, generate, review, and export actions

- [ ] **Step 1: Write failing store tests**

```swift
// Tests/EchoDeckBuilderTests/LibraryStoreTests.swift
import XCTest
@testable import EchoDeckBuilder

final class LibraryStoreTests: XCTestCase {
    func testAcceptingCardChangesReviewState() throws {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
        let section = BookSection(spineIndex: 1, blockIndex: 1, heading: "Intro", text: "Text", anchor: anchor)
        let card = DeckCard(sectionID: section.id, frontText: "Front", backText: "Back", kind: .basic, sourceAnchor: anchor)
        let store = LibraryStore(sections: [section], cards: [card])
        store.targetMediaID = "file:///Books/Example"

        store.accept(cardID: card.id)

        XCTAssertEqual(store.cards.first?.reviewState, .accepted)
        XCTAssertTrue(store.canExportEchoDeck)
    }
}
```

- [ ] **Step 2: Implement store state and commands**

```swift
// Sources/EchoDeckBuilder/Stores/LibraryStore.swift
import Foundation
import Observation

@Observable
public final class LibraryStore {
    public var sections: [BookSection]
    public var cards: [DeckCard]
    public var selectedSectionID: BookSection.ID?
    public var selectedCardID: DeckCard.ID?
    public var deckName: String
    public var targetMediaID: String
    public var statusMessage: String
    public var isInspectorPresented: Bool

    private let generator: any CardGenerator

    public init(
        sections: [BookSection] = [],
        cards: [DeckCard] = [],
        generator: any CardGenerator = FixtureCardGenerator()
    ) {
        self.sections = sections
        self.cards = cards
        self.selectedSectionID = sections.first?.id
        self.selectedCardID = cards.first?.id
        self.deckName = "Untitled Deck"
        self.targetMediaID = ""
        self.statusMessage = "Ready"
        self.isInspectorPresented = true
        self.generator = generator
    }

    public var selectedSection: BookSection? {
        sections.first { $0.id == selectedSectionID }
    }

    public var selectedCard: DeckCard? {
        cards.first { $0.id == selectedCardID }
    }

    public var canGenerateCards: Bool {
        !sections.isEmpty
    }

    public var canExportEchoDeck: Bool {
        !targetMediaID.isEmpty && cards.contains { $0.reviewState == .accepted }
    }

    public func requestImportPanel() {
        statusMessage = "Use File > Import EPUB... to choose a local EPUB"
    }

    public func requestEchoExportPanel() {
        statusMessage = canExportEchoDeck ? "Echo deck export is ready" : "Accept at least one card and set a target media ID"
    }

    public func generateCardsForSelectedBook() {
        Task { @MainActor in
            do {
                cards = try await generator.generateCards(for: sections)
                selectedCardID = cards.first?.id
                statusMessage = "Generated \(cards.count) draft cards"
            } catch {
                statusMessage = "Card generation failed: \(error.localizedDescription)"
            }
        }
    }

    public func accept(cardID: DeckCard.ID) {
        update(cardID: cardID) { $0.reviewState = .accepted }
    }

    public func reject(cardID: DeckCard.ID) {
        update(cardID: cardID) { $0.reviewState = .rejected }
    }

    public func update(cardID: DeckCard.ID, mutate: (inout DeckCard) -> Void) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        mutate(&cards[index])
    }
}
```

- [ ] **Step 3: Replace app entrypoint with store-backed commands**

```swift
// Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift
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
```

- [ ] **Step 4: Replace root view with split review shell**

```swift
// Sources/EchoDeckBuilder/Views/ContentView.swift
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
```

- [ ] **Step 5: Implement sidebar**

```swift
// Sources/EchoDeckBuilder/Views/SidebarView.swift
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
```

- [ ] **Step 6: Implement section list**

```swift
// Sources/EchoDeckBuilder/Views/SectionListView.swift
import SwiftUI

struct SectionListView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        List(selection: $store.selectedCardID) {
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
}
```

- [ ] **Step 7: Implement card review**

```swift
// Sources/EchoDeckBuilder/Views/CardReviewView.swift
import SwiftUI

struct CardReviewView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        Group {
            if let cardID = store.selectedCardID, let card = store.selectedCard {
                Form {
                    TextField("Front", text: Binding(
                        get: { card.frontText },
                        set: { newValue in store.update(cardID: cardID) { $0.frontText = newValue } }
                    ), axis: .vertical)

                    TextField("Back", text: Binding(
                        get: { card.backText },
                        set: { newValue in store.update(cardID: cardID) { $0.backText = newValue } }
                    ), axis: .vertical)

                    Picker("Kind", selection: Binding(
                        get: { card.kind },
                        set: { newValue in store.update(cardID: cardID) { $0.kind = newValue } }
                    )) {
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
```

- [ ] **Step 8: Implement inspector**

```swift
// Sources/EchoDeckBuilder/Views/InspectorView.swift
import SwiftUI

struct InspectorView: View {
    @Bindable var store: LibraryStore

    var body: some View {
        Form {
            Section("Deck") {
                TextField("Deck name", text: $store.deckName)
                TextField("Target media ID", text: $store.targetMediaID)
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
}
```

- [ ] **Step 9: Run store tests and app build**

Run: `swift test --filter LibraryStoreTests && swift build`

Expected: PASS for tests and build.

- [ ] **Step 10: Commit**

```bash
git add Sources/EchoDeckBuilder/Stores Sources/EchoDeckBuilder/Views Tests/EchoDeckBuilderTests/LibraryStoreTests.swift
git commit -m "feat: add review shell and library store"
```

---

### Task 8: Import And Export Commands

**Files:**
- Modify: `Sources/EchoDeckBuilder/Stores/LibraryStore.swift`
- Modify: `Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift`
- Modify: `Sources/EchoDeckBuilder/Views/ContentView.swift`
- Create: `Sources/EchoDeckBuilder/Services/EPUBContainerParser.swift`
- Test: `Tests/EchoDeckBuilderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `EPUBArchiveExtractor`, `EPUBManifestParser`, `XHTMLBlockExtractor`, exporters
- Produces: `LibraryStore.importEPUB(at:) async`
- Produces: `LibraryStore.echoDeckJSONData() throws -> Data`
- Produces: `LibraryStore.ankiTSV() -> String`

- [ ] **Step 1: Add store tests for export data**

```swift
func testEchoDeckJSONDataUsesAcceptedCardsAndTargetMediaID() throws {
    let anchor = try XCTUnwrap(SourceAnchor(suffix: "s1-b1"))
    let section = BookSection(spineIndex: 1, blockIndex: 1, heading: "Intro", text: "Text", anchor: anchor)
    var card = DeckCard(sectionID: section.id, frontText: "Front", backText: "Back", kind: .basic, sourceAnchor: anchor)
    card.reviewState = .accepted
    let store = LibraryStore(sections: [section], cards: [card])
    store.deckName = "Intro Deck"
    store.targetMediaID = "file:///Books/Example"

    let data = try store.echoDeckJSONData()
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

    XCTAssertEqual(object["deckName"] as? String, "Intro Deck")
    XCTAssertEqual(object["targetMediaID"] as? String, "file:///Books/Example")
}
```

- [ ] **Step 2: Add store import and export methods**

```swift
public func importEPUB(at epubURL: URL) async {
    do {
        let extractedURL = try await EPUBArchiveExtractor().extract(epubURL: epubURL)
        let containerURL = extractedURL.appendingPathComponent("META-INF/container.xml")
        let containerData = try Data(contentsOf: containerURL)
        let packagePath = try EPUBContainerParser().packagePath(from: containerData)
        let packageURL = extractedURL.appendingPathComponent(packagePath)
        let packageData = try Data(contentsOf: packageURL)
        let packageDirectory = packageURL.deletingLastPathComponent()
        let spineItems = try EPUBManifestParser().spineItems(fromPackageData: packageData, packageDirectory: packageDirectory)
        let extractor = XHTMLBlockExtractor()

        var importedSections: [BookSection] = []
        for item in spineItems {
            let data = try Data(contentsOf: item.fileURL)
            importedSections.append(contentsOf: try extractor.sections(from: data, spineIndex: item.spineIndex))
        }

        sections = importedSections
        cards = []
        selectedSectionID = sections.first?.id
        selectedCardID = nil
        deckName = epubURL.deletingPathExtension().lastPathComponent
        statusMessage = "Imported \(sections.count) anchored sections"
    } catch {
        statusMessage = "EPUB import failed: \(error.localizedDescription)"
    }
}

public func echoDeckJSONData() throws -> Data {
    try EchoDeckJSONExporter().export(deckName: deckName, targetMediaID: targetMediaID, cards: cards)
}

public func ankiTSV() -> String {
    AnkiTSVExporter().export(cards: cards)
}
```

- [ ] **Step 3: Add container parser used by import**

```swift
// Sources/EchoDeckBuilder/Services/EPUBContainerParser.swift
import Foundation

public final class EPUBContainerParser: NSObject, XMLParserDelegate {
    private var rootfilePath: String?

    public func packagePath(from data: Data) throws -> String {
        rootfilePath = nil
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        guard let rootfilePath else {
            throw EPUBExtractionError.containerMissingRootfile
        }
        return rootfilePath
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName.lowercased() == "rootfile" {
            rootfilePath = attributeDict["full-path"]
        }
    }
}
```

- [ ] **Step 4: Wire import panel in app commands**

```swift
// Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

private func chooseEPUB() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.epub]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK, let url = panel.url {
        Task { await library.importEPUB(at: url) }
    }
}
```

Use the helper from `EchoDeckBuilderApp` command actions and the toolbar import action so both paths call the same store method. Pass the helper into `ContentView`:

```swift
// Sources/EchoDeckBuilder/App/EchoDeckBuilderApp.swift
WindowGroup("EchoDeckBuilder", id: "main") {
    ContentView(store: library, importEPUB: chooseEPUB)
        .frame(minWidth: 1040, minHeight: 680)
}
```

```swift
// Sources/EchoDeckBuilder/Views/ContentView.swift
struct ContentView: View {
    @Bindable var store: LibraryStore
    let importEPUB: () -> Void

    var body: some View {
        // existing split view
        .toolbar {
            ToolbarItemGroup {
                Button {
                    importEPUB()
                } label: {
                    Label("Import EPUB", systemImage: "square.and.arrow.down")
                }

                // keep the existing Generate Cards and Export Echo Deck buttons
            }
        }
    }
}
```

- [ ] **Step 5: Run command tests and build**

Run: `swift test --filter LibraryStoreTests && swift build`

Expected: PASS for tests and build.

- [ ] **Step 6: Commit**

```bash
git add Sources/EchoDeckBuilder Tests/EchoDeckBuilderTests/LibraryStoreTests.swift
git commit -m "feat: wire epub import and deck export commands"
```

---

### Task 9: End-To-End Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-06-25-echo-deck-builder-mvp.md`

**Interfaces:**
- Consumes: full app pipeline from Tasks 1-8
- Produces: verified local build/test/run instructions

- [ ] **Step 1: Run all tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 2: Build and verify app launch**

Run: `./script/build_and_run.sh --verify`

Expected: exit code 0 and `pgrep -x EchoDeckBuilder` finds a running process.

- [ ] **Step 3: Update README with actual build commands**

Add this section to `README.md`:

````markdown
## Build And Run

Run tests:

```bash
swift test
```

Build and launch the macOS app:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```
````

- [ ] **Step 4: Review export JSON against the README contract**

Run: `swift test --filter EchoDeckJSONExporterTests`

Expected: PASS, and exported cards contain `sourceAnchor` values shaped like `s<i>-b<j>`.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/plans/2026-06-25-echo-deck-builder-mvp.md
git commit -m "docs: add build verification notes"
```

---

## Self-Review

**Spec coverage:**

- README source-anchor contract is represented by `SourceAnchor`, `BookSection.anchor`, `DeckCard.sourceAnchor`, and `EchoDeckJSONExporter`.
- Portable suffix format `s<i>-b<j>` is tested by `SourceAnchorTests` and `XHTMLBlockExtractorTests`.
- Echo JSON vNext `sourceAnchor` export is tested by `EchoDeckJSONExporterTests`.
- Existing Echo importer behavior is treated as an external assumption, not implemented in this repo.
- APKG sidecar generation is not in this MVP plan because APKG archive creation is an independent subsystem; TSV export keeps Anki review usable for the first pipeline.
- Live AI provider calls are not in this MVP plan because local deterministic generation protects privacy while the extraction, review, and export surfaces are being proven.

**Red-flag scan:**

- No unfinished-work marker strings are present.
- Each implementation step names concrete files, commands, and expected outcomes.

**Type consistency:**

- `SourceAnchor.suffix` is used consistently by models, generators, and exporters.
- `BookSection.ID` and `DeckCard.ID` are `UUID` through `Identifiable` structs.
- `LibraryStore` methods match the names used by `ContentView` and tests.
