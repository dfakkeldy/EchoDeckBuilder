import Foundation

public enum FoundationModelCardPrompt {
    public static let maximumSectionCharacters = 7_500

    public static let instructions = """
    You generate study flashcards from private EPUB sections.
    Only use the supplied EPUB section. Do not add outside facts or world knowledge.
    Create one high-signal draft card when the section has enough substance.
    Use a basic question or a cloze sentence depending on what best fits the source.
    Paraphrase the source. Do not copy long passages or long headings verbatim.
    Keep the answer short, concrete, and useful for review.
    Do not create or change source anchors.
    Return useful tags, but avoid generic tags like book, section, flashcard, or study.
    """

    public static func prompt(
        for section: BookSection,
        maxCharacters: Int = maximumSectionCharacters
    ) -> String {
        let sourceExcerpt = excerpt(from: section.text, maxCharacters: maxCharacters)
        return """
        Generate a draft study card from this EPUB section.

        Source anchor: \(section.anchor.suffix)
        Heading: \(section.heading)
        Spine index: \(section.spineIndex)
        Block index: \(section.blockIndex)

        Do not create or change source anchors.
        Base the card only on this source excerpt:

        \(sourceExcerpt)
        """
    }

    public static func excerpt(from text: String, maxCharacters: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard maxCharacters > 0 else {
            return ""
        }

        guard trimmed.count > maxCharacters else {
            return trimmed
        }

        let limit = trimmed.index(trimmed.startIndex, offsetBy: maxCharacters)
        let prefix = String(trimmed[..<limit])
        if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
            return String(prefix[...sentenceEnd])
        }

        return prefix
    }
}
