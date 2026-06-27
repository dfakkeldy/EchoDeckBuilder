import Foundation
import XCTest

struct TestEPUBFixture {
    let epubURL: URL
    let rootURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    static func make(
        rootfilePath: String = "OEBPS/content.opf",
        manifestHref: String = "Text/chapter1.xhtml#body"
    ) throws -> TestEPUBFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderTests-\(UUID().uuidString)", isDirectory: true)
        let contentRoot = rootURL.appendingPathComponent("content", isDirectory: true)
        let metaInfURL = contentRoot.appendingPathComponent("META-INF", isDirectory: true)
        let packageURL = contentRoot.appendingPathComponent(rootfilePath)
        let packageDirectory = packageURL.deletingLastPathComponent()
        let chapterURL = packageDirectory
            .appendingPathComponent("Text", isDirectory: true)
            .appendingPathComponent("chapter1.xhtml")
        let epubURL = rootURL.appendingPathComponent("fixture.epub")

        try FileManager.default.createDirectory(at: metaInfURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: chapterURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="\(rootfilePath)" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.utf8).write(to: metaInfURL.appendingPathComponent("container.xml"))

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <manifest>
            <item id="chap1" href="\(manifestHref)" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chap1"/>
          </spine>
        </package>
        """.utf8).write(to: packageURL)

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1>Fixture Chapter</h1>
            <p>This fixture paragraph becomes one anchored section.</p>
          </body>
        </html>
        """.utf8).write(to: chapterURL)

        try zipDirectory(contentRoot, outputURL: epubURL)
        return TestEPUBFixture(epubURL: epubURL, rootURL: rootURL)
    }

    static func makeEchoParserParityFixture() throws -> TestEPUBFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderTests-\(UUID().uuidString)", isDirectory: true)
        let contentRoot = rootURL.appendingPathComponent("content", isDirectory: true)
        let metaInfURL = contentRoot.appendingPathComponent("META-INF", isDirectory: true)
        let epubURL = rootURL.appendingPathComponent("echo-parser-parity.epub")

        try FileManager.default.createDirectory(at: metaInfURL, withIntermediateDirectories: true)

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.utf8).write(to: metaInfURL.appendingPathComponent("container.xml"))

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata><title>Test Book</title></metadata>
          <manifest>
            <item id="chap1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="chap2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chap1"/>
            <itemref idref="chap2"/>
          </spine>
        </package>
        """.utf8).write(to: contentRoot.appendingPathComponent("content.opf"))

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter One</title></head>
        <body>
          <h1>Chapter One</h1>
          <p>It was a dark and stormy night.</p>
          <img src="images/scene.jpg"/>
          <p>The rain fell in torrents.</p>
        </body>
        </html>
        """.utf8).write(to: contentRoot.appendingPathComponent("chapter1.xhtml"))

        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Morning</title></head>
        <body>
          <p>The morning brought clear skies and a gentle breeze.</p>
          <p>Everyone felt the day would be a good one.</p>
        </body>
        </html>
        """.utf8).write(to: contentRoot.appendingPathComponent("chapter2.xhtml"))

        try zipDirectory(contentRoot, outputURL: epubURL)
        return TestEPUBFixture(epubURL: epubURL, rootURL: rootURL)
    }

    private static func zipDirectory(_ directoryURL: URL, outputURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qry", outputURL.path, "."]
        process.currentDirectoryURL = directoryURL

        let standardError = Pipe()
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "zip exited with \(process.terminationStatus)"
            XCTFail(message)
            return
        }
    }
}
