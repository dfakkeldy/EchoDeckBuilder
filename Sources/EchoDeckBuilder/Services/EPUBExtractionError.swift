import Foundation

public enum EPUBExtractionError: Error, Equatable, Sendable {
    case unzipFailed(String)
    case invalidArchiveEntryPath(String)
    case invalidEPUBPath(String)
    case containerParseFailed(String)
    case containerMissingRootfile
    case packageMissingSpine
    case manifestItemMissing(String)
    case xhtmlParseFailed(String)
}

extension EPUBExtractionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unzipFailed(message):
            "EPUB unzip failed: \(message)"
        case let .invalidArchiveEntryPath(path):
            "EPUB archive contains an unsafe entry path: \(path)"
        case let .invalidEPUBPath(path):
            "EPUB references an unsafe path: \(path)"
        case let .containerParseFailed(message):
            "EPUB container parse failed: \(message)"
        case .containerMissingRootfile:
            "EPUB container is missing a rootfile entry"
        case .packageMissingSpine:
            "EPUB package is missing a readable spine"
        case let .manifestItemMissing(id):
            "EPUB manifest is missing item '\(id)'"
        case let .xhtmlParseFailed(message):
            "EPUB XHTML parse failed: \(message)"
        }
    }
}
