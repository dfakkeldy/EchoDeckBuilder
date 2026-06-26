import Foundation

public struct BookBrief: Codable, Hashable, Sendable {
    public var summary: String
    public var themes: [String]
    public var keyConcepts: [String]
    public var argumentFlow: [String]
    public var skipAreas: [String]

    public init(
        summary: String,
        themes: [String] = [],
        keyConcepts: [String] = [],
        argumentFlow: [String] = [],
        skipAreas: [String] = []
    ) {
        self.summary = summary
        self.themes = themes
        self.keyConcepts = keyConcepts
        self.argumentFlow = argumentFlow
        self.skipAreas = skipAreas
    }

    public static let fixture = BookBrief(
        summary: "Fixture generator created deterministic local draft cards.",
        themes: ["local deterministic generation"],
        keyConcepts: ["source anchors", "reviewable drafts"],
        argumentFlow: ["extract sections", "create draft cards", "review into deck"],
        skipAreas: []
    )
}
