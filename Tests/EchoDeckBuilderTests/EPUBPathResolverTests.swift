import XCTest
@testable import EchoDeckBuilder

final class EPUBPathResolverTests: XCTestCase {
    func testDecodesURIPathAndStripsFragment() throws {
        let path = try EPUBPathResolver.decodedRelativePath(fromURI: "Text/Chapter%201.xhtml#chapter")

        XCTAssertEqual(path, "Text/Chapter 1.xhtml")
    }

    func testRejectsUnsafeURIPaths() {
        let unsafePaths = [
            "",
            "/etc/passwd",
            "file:///etc/passwd",
            "../outside.xhtml",
            "Text/%2e%2e/outside.xhtml",
            "Text//chapter.xhtml",
            #"Text\chapter.xhtml"#
        ]

        for path in unsafePaths {
            XCTAssertThrowsError(try EPUBPathResolver.decodedRelativePath(fromURI: path), path)
        }
    }

    func testResolveRejectsPathsOutsidePackageRoot() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("book", isDirectory: true)
            .appendingPathComponent("OEBPS", isDirectory: true)
        let resolver = EPUBPathResolver(rootURL: root)

        XCTAssertThrowsError(try resolver.resolveEPUBPath("../outside.xhtml", relativeTo: root))
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
