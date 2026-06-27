import XCTest
@testable import EchoDeckBuilder

@MainActor
final class EPUBImportIntegrationTests: XCTestCase {
    func testImportsGeneratedEPUBAndCleansTemporaryExtractionDirectory() async throws {
        let fixture = try TestEPUBFixture.make()
        defer { fixture.cleanup() }

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent(
            "EchoDeckBuilder",
            isDirectory: true
        )
        let before = temporaryExtractionDirectoryNames(in: tempBase)
        let store = LibraryStore()

        await store.importEPUB(at: fixture.epubURL)

        XCTAssertEqual(store.sections.count, 1)
        XCTAssertEqual(store.sections.first?.heading, "Fixture Chapter")
        XCTAssertEqual(store.sections.first?.anchor.suffix, "s0-b1")
        XCTAssertEqual(store.statusMessage, "Imported 1 anchored sections")
        XCTAssertEqual(temporaryExtractionDirectoryNames(in: tempBase), before)
    }

    func testImportsWithEchoCompatibleZeroBasedAnchorsAndSyntheticHeadings() async throws {
        let fixture = try TestEPUBFixture.makeEchoParserParityFixture()
        defer { fixture.cleanup() }

        let store = LibraryStore()

        await store.importEPUB(at: fixture.epubURL)

        XCTAssertEqual(
            store.sections.map(\.anchor.suffix),
            ["s0-b1", "s0-b3", "s1-b1", "s1-b2"]
        )
        XCTAssertEqual(
            store.sections.map(\.heading),
            ["Chapter One", "Chapter One", "Morning", "Morning"]
        )
        XCTAssertEqual(
            store.sections.map(\.text),
            [
                "It was a dark and stormy night.",
                "The rain fell in torrents.",
                "The morning brought clear skies and a gentle breeze.",
                "Everyone felt the day would be a good one."
            ]
        )
        XCTAssertEqual(store.statusMessage, "Imported 4 anchored sections")
    }

    private func temporaryExtractionDirectoryNames(in tempBase: URL) -> Set<String> {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempBase,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return Set(contents.map(\.lastPathComponent))
    }
}
