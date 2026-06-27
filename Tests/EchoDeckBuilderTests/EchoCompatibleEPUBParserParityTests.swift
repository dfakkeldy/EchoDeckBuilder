import XCTest
@testable import EchoDeckBuilder

final class EchoCompatibleEPUBParserParityTests: XCTestCase {
    func testImageBlocksAdvanceAnchorOffsetsButDoNotBecomeSections() async throws {
        let fixture = try TestEPUBFixture.makeEchoParserParityFixture()
        defer { fixture.cleanup() }

        let extractedURL = try await EPUBArchiveExtractor().extract(epubURL: fixture.epubURL)
        defer { try? FileManager.default.removeItem(at: extractedURL) }

        let sections = try EchoCompatibleEPUBParser().sections(fromExtractedEPUBRoot: extractedURL)

        XCTAssertEqual(sections.map(\.anchor.suffix), ["s0-b1", "s0-b3", "s1-b1", "s1-b2"])
        XCTAssertEqual(sections.map(\.heading), ["Chapter One", "Chapter One", "Morning", "Morning"])
    }

    func testLinearNoFrontMatterKeepsEchoStyleBlockOffsets() async throws {
        let fixture = try TestEPUBFixture.makeFrontMatterAndBodyMatterFixture()
        defer { fixture.cleanup() }

        let extractedURL = try await EPUBArchiveExtractor().extract(epubURL: fixture.epubURL)
        defer { try? FileManager.default.removeItem(at: extractedURL) }

        let sections = try EchoCompatibleEPUBParser().sections(fromExtractedEPUBRoot: extractedURL)

        XCTAssertEqual(sections.map(\.anchor.suffix), ["s0-b1", "s1-b1"])
        XCTAssertEqual(sections.map(\.heading), ["Cover", "Chapter One"])
        XCTAssertEqual(sections.map(\.text), [
            "Marketing copy that should not become a generated study section.",
            "The first real body paragraph."
        ])
    }
}
