import Foundation
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
