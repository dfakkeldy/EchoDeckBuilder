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

        let items = try EPUBManifestParser().spineItems(fromPackageData: Data(opf.utf8), packageDirectory: URL(fileURLWithPath: "/tmp/book/OEBPS"))

        XCTAssertEqual(items.map(\.spineIndex), [1, 2])
        XCTAssertEqual(items.map(\.href), ["Text/chapter1.xhtml", "Text/chapter2.xhtml"])
    }
}
