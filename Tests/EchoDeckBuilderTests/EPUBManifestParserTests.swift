import Foundation
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

        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderManifestTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("OEBPS", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packageDirectory.deletingLastPathComponent()) }

        let items = try EPUBManifestParser().spineItems(
            fromPackageData: Data(opf.utf8),
            packageDirectory: packageDirectory
        )

        XCTAssertEqual(items.map(\.spineIndex), [1, 2])
        XCTAssertEqual(items.map(\.href), ["Text/chapter1.xhtml", "Text/chapter2.xhtml"])
    }

    func testResolvesManifestHrefsAsDecodedPackageRelativePathsWithoutFragments() throws {
        let fixture = try TestEPUBFixture.make(manifestHref: "Text/chapter%201.xhtml#page")
        defer { fixture.cleanup() }

        let packageDirectory = fixture.rootURL
            .appendingPathComponent("content", isDirectory: true)
            .appendingPathComponent("OEBPS", isDirectory: true)
        let chapterURL = packageDirectory
            .appendingPathComponent("Text", isDirectory: true)
            .appendingPathComponent("chapter 1.xhtml")
        try FileManager.default.moveItem(
            at: packageDirectory.appendingPathComponent("Text/chapter1.xhtml"),
            to: chapterURL
        )
        let opfURL = packageDirectory.appendingPathComponent("content.opf")
        let items = try EPUBManifestParser().spineItems(
            fromPackageData: Data(contentsOf: opfURL),
            packageDirectory: packageDirectory
        )

        XCTAssertEqual(items.first?.fileURL, chapterURL.standardizedFileURL.resolvingSymlinksInPath())
    }

    func testAcceptsManifestHrefWithDotSegmentsInsideExtractionRoot() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf">
          <manifest>
            <item id="chap1" href="../Text/./chapter%201.xhtml?version=1#body" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chap1"/>
          </spine>
        </package>
        """
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderManifestTests-\(UUID().uuidString)", isDirectory: true)
        let packageDirectory = rootURL
            .appendingPathComponent("OEBPS", isDirectory: true)
            .appendingPathComponent("Package", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let items = try EPUBManifestParser().spineItems(
            fromPackageData: Data(opf.utf8),
            packageDirectory: packageDirectory,
            extractionRootURL: rootURL
        )
        let expected = rootURL
            .appendingPathComponent("OEBPS", isDirectory: true)
            .appendingPathComponent("Text", isDirectory: true)
            .appendingPathComponent("chapter 1.xhtml")
            .standardizedFileURL
            .resolvingSymlinksInPath()

        XCTAssertEqual(items.first?.fileURL, expected)
    }

    func testRejectsManifestHrefTraversalOutsideExtractionRoot() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf">
          <manifest>
            <item id="chap1" href="../../outside.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chap1"/>
          </spine>
        </package>
        """
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderManifestTests-\(UUID().uuidString)", isDirectory: true)
        let packageDirectory = rootURL.appendingPathComponent("OEBPS", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        XCTAssertThrowsError(
            try EPUBManifestParser().spineItems(
                fromPackageData: Data(opf.utf8),
                packageDirectory: packageDirectory,
                extractionRootURL: rootURL
            )
        )
    }
}
