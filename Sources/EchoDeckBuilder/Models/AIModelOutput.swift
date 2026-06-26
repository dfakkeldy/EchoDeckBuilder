import Foundation

public struct AIModelOutput: Codable, Hashable, Sendable {
    public var run: Run
    public var bookBrief: Brief
    public var cards: [Card]
    public var warnings: [String]

    public init(run: Run, bookBrief: Brief, cards: [Card], warnings: [String]) {
        self.run = run
        self.bookBrief = bookBrief
        self.cards = cards
        self.warnings = warnings
    }

    public struct Run: Codable, Hashable, Sendable {
        public var provider: String
        public var model: String
        public var sourceScope: String
        public var imageMode: String

        public init(provider: String, model: String, sourceScope: String, imageMode: String) {
            self.provider = provider
            self.model = model
            self.sourceScope = sourceScope
            self.imageMode = imageMode
        }
    }

    public struct Brief: Codable, Hashable, Sendable {
        public var summary: String
        public var themes: [String]
        public var keyConcepts: [String]
        public var argumentFlow: [String]
        public var skipAreas: [String]

        public init(summary: String, themes: [String], keyConcepts: [String], argumentFlow: [String], skipAreas: [String]) {
            self.summary = summary
            self.themes = themes
            self.keyConcepts = keyConcepts
            self.argumentFlow = argumentFlow
            self.skipAreas = skipAreas
        }
    }

    public struct Card: Codable, Hashable, Sendable {
        public var sourceAnchor: String
        public var kind: String
        public var frontText: String
        public var backText: String
        public var clozeText: String?
        public var tags: [String]
        public var importance: Double
        public var confidence: Double
        public var rationale: String
        public var visual: Visual?

        public init(
            sourceAnchor: String,
            kind: String,
            frontText: String,
            backText: String,
            clozeText: String?,
            tags: [String],
            importance: Double,
            confidence: Double,
            rationale: String,
            visual: Visual?
        ) {
            self.sourceAnchor = sourceAnchor
            self.kind = kind
            self.frontText = frontText
            self.backText = backText
            self.clozeText = clozeText
            self.tags = tags
            self.importance = importance
            self.confidence = confidence
            self.rationale = rationale
            self.visual = visual
        }
    }

    public struct Visual: Codable, Hashable, Sendable {
        public var priority: String
        public var imagePrompt: String
        public var altText: String

        public init(priority: String, imagePrompt: String, altText: String) {
            self.priority = priority
            self.imagePrompt = imagePrompt
            self.altText = altText
        }
    }
}
