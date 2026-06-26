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
        XCTAssertEqual(store.sections.first?.anchor.suffix, "s1-b1")
        XCTAssertEqual(store.statusMessage, "Imported 1 anchored sections")
        XCTAssertEqual(temporaryExtractionDirectoryNames(in: tempBase), before)
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
