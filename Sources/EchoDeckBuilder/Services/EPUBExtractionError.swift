import Foundation

public enum EPUBExtractionError: Error, Equatable, Sendable {
    case unzipFailed(String)
    case containerMissingRootfile
    case packageMissingSpine
    case manifestItemMissing(String)
    case xhtmlParseFailed(String)
}
