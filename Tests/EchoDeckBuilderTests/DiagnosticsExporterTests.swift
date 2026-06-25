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
