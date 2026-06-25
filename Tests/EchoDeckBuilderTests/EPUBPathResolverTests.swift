import XCTest
@testable import EchoDeckBuilder

final class EPUBPathResolverTests: XCTestCase {
    func testDecodesURIPathAndStripsFragment() throws {
        let path = try EPUBPathResolver.decodedRelativePath(fromURI: "Text/Chapter%201.xhtml?view=full#chapter")

        XCTAssertEqual(path, "Text/Chapter 1.xhtml")
    }

    func testRejectsUnsafeURIPaths() {
        let unsafePaths = [
            "",
            "/etc/passwd",
            "file:///etc/passwd",
            "Text//chapter.xhtml",
            "Text/chapter%2F1.xhtml",
            #"Text\chapter.xhtml"#
        ]

        for path in unsafePaths {
            XCTAssertThrowsError(try EPUBPathResolver.decodedRelativePath(fromURI: path), path)
        }
    }

    func testResolveAllowsDotSegmentsWithinExtractionRoot() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("EchoDeckBuilderPathTests-\(UUID().uuidString)", isDirectory: true)
        let packageDirectory = root
            .appendingPathComponent("OEBPS", isDirectory: true)
            .appendingPathComponent("Package", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = EPUBPathResolver(rootURL: root)
        let resolved = try resolver.resolveEPUBPath("../Text/./chapter.xhtml#body", relativeTo: packageDirectory)
        let expected = root
            .appendingPathComponent("OEBPS", isDirectory: true)
            .appendingPathComponent("Text", isDirectory: true)
            .appendingPathComponent("chapter.xhtml")
            .standardizedFileURL
            .resolvingSymlinksInPath()

        XCTAssertEqual(resolved, expected)
    }

    func testResolveRejectsDotSegmentsOutsideExtractionRoot() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("EchoDeckBuilderPathTests-\(UUID().uuidString)", isDirectory: true)
        let packageDirectory = root.appendingPathComponent("OEBPS", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let resolver = EPUBPathResolver(rootURL: root)

        XCTAssertThrowsError(try resolver.resolveEPUBPath("../../outside.xhtml", relativeTo: packageDirectory))
    }

    func testArchiveEntryValidationRejectsTraversalAndAbsolutePaths() {
        let unsafePaths = [
            "",
            "/OPS/content.opf",
            "../content.opf",
            "OPS/../content.opf",
            "OPS//content.opf",
            #"OPS\content.opf"#
        ]

        for path in unsafePaths {
            XCTAssertThrowsError(try EPUBPathResolver.validateArchiveEntryPath(path), path)
        }
    }

    func testArchiveEntryValidationAllowsNormalFilesAndDirectories() throws {
        try EPUBPathResolver.validateArchiveEntryPath("META-INF/container.xml")
        try EPUBPathResolver.validateArchiveEntryPath("OEBPS/Text/")
    }
}
