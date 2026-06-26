import XCTest
@testable import EchoDeckBuilder

final class GenerationBatcherTests: XCTestCase {
    func testGroupsSectionsBySpineAndBatchSize() throws {
        let sections = try [
            makeSection(spine: 1, block: 1),
            makeSection(spine: 1, block: 2),
            makeSection(spine: 1, block: 3),
            makeSection(spine: 2, block: 1)
        ]

        let batches = GenerationBatcher().batches(from: sections, maxSectionsPerBatch: 2)

        XCTAssertEqual(batches.map { $0.map(\.anchor.suffix) }, [["s1-b1", "s1-b2"], ["s1-b3"], ["s2-b1"]])
    }

    func testEmptySectionsProduceNoBatches() {
        XCTAssertEqual(GenerationBatcher().batches(from: [], maxSectionsPerBatch: 12), [])
    }

    private func makeSection(spine: Int, block: Int) throws -> BookSection {
        let anchor = try XCTUnwrap(SourceAnchor(suffix: "s\(spine)-b\(block)"))
        return BookSection(
            spineIndex: spine,
            blockIndex: block,
            heading: "Heading \(spine).\(block)",
            text: "Text \(spine).\(block)",
            anchor: anchor
        )
    }
}
