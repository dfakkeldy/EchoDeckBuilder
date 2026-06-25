import Foundation

public final class XHTMLBlockExtractor: NSObject, XMLParserDelegate {
    private var spineIndex = 0
    private var currentHeading = "Untitled Section"
    private var currentText = ""
    private var activeElement: String?
    private var pendingBlocks: [(heading: String, text: String)] = []

    public override init() {
        super.init()
    }

    public func sections(from data: Data, spineIndex: Int) throws -> [BookSection] {
        self.spineIndex = spineIndex
        currentHeading = "Untitled Section"
        currentText = ""
        activeElement = nil
        pendingBlocks = []

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw EPUBExtractionError.xhtmlParseFailed(parser.parserError?.localizedDescription ?? "Unknown XML parse error")
        }

        return pendingBlocks.enumerated().compactMap { offset, block in
            let blockIndex = offset + 1
            guard let anchor = SourceAnchor(suffix: "s\(spineIndex)-b\(blockIndex)") else {
                return nil
            }

            return BookSection(
                spineIndex: spineIndex,
                blockIndex: blockIndex,
                heading: block.heading,
                text: block.text,
                anchor: anchor
            )
        }
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = elementName.lowercased()
        if Self.headingElements.contains(element) || Self.blockElements.contains(element) {
            activeElement = element
            currentText = ""
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard activeElement != nil else { return }
        currentText += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = elementName.lowercased()
        guard element == activeElement else { return }

        let normalized = currentText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.headingElements.contains(element) {
            if !normalized.isEmpty {
                currentHeading = normalized
            }
        } else if Self.blockElements.contains(element) {
            if !normalized.isEmpty {
                pendingBlocks.append((heading: currentHeading, text: normalized))
            }
        }

        activeElement = nil
        currentText = ""
    }

    private static let headingElements: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
    private static let blockElements: Set<String> = ["p", "blockquote", "li"]
}
