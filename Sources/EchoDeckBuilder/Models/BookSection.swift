import Foundation

public struct BookSection: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var spineIndex: Int
    public var blockIndex: Int
    public var heading: String
    public var text: String
    public var anchor: SourceAnchor

    public init(
        id: UUID = UUID(),
        spineIndex: Int,
        blockIndex: Int,
        heading: String,
        text: String,
        anchor: SourceAnchor
    ) {
        self.id = id
        self.spineIndex = spineIndex
        self.blockIndex = blockIndex
        self.heading = heading
        self.text = text
        self.anchor = anchor
    }
}
