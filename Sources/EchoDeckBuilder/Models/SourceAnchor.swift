import Foundation

public struct SourceAnchor: Codable, Hashable, Identifiable, Sendable {
    public var id: String { suffix }
    public let suffix: String

    public init?(suffix: String) {
        guard Self.isCanonicalSuffix(suffix) else { return nil }
        self.suffix = suffix
    }

    public static func parse(_ rawValue: String?) -> SourceAnchor? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCanonicalSuffix(trimmed) {
            return SourceAnchor(suffix: trimmed)
        }
        guard let range = trimmed.range(of: #"s[0-9]+-b[0-9]+$"#, options: .regularExpression) else {
            return nil
        }
        return SourceAnchor(suffix: String(trimmed[range]))
    }

    public func fullEchoBlockID(targetMediaID: String) -> String {
        "epub-\(targetMediaID)-\(suffix)"
    }

    private static func isCanonicalSuffix(_ value: String) -> Bool {
        value.range(of: #"^s[0-9]+-b[0-9]+$"#, options: .regularExpression) != nil
    }
}
