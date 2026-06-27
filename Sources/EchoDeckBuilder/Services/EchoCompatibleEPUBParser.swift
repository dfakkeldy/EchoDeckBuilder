import Foundation

public struct EchoCompatibleEPUBParser: Sendable {
    public init() {}

    public func sections(fromExtractedEPUBRoot rootURL: URL) throws -> [BookSection] {
        let blocks = try EchoEPUBBlockParser(rootURL: rootURL).parse()
        return Self.sections(from: blocks)
    }

    private static func sections(from blocks: [EchoEPUBBlock]) -> [BookSection] {
        var currentHeading = "Untitled Section"
        var sections: [BookSection] = []

        for block in blocks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }) {
            guard let text = block.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                continue
            }

            switch block.kind {
            case .heading:
                currentHeading = text
            case .paragraph, .sentence:
                guard let anchor = SourceAnchor(suffix: "s\(block.spineIndex)-b\(block.blockIndex)") else {
                    continue
                }
                sections.append(
                    BookSection(
                        spineIndex: block.spineIndex,
                        blockIndex: block.blockIndex,
                        heading: currentHeading,
                        text: text,
                        anchor: anchor
                    )
                )
            case .image:
                continue
            }
        }

        return sections
    }
}

private struct EchoEPUBBlock: Hashable, Sendable {
    enum Kind: String, Sendable {
        case heading
        case paragraph
        case sentence
        case image
    }

    var id: String
    var spineHref: String
    var spineIndex: Int
    var blockIndex: Int
    var sequenceIndex: Int
    var kind: Kind
    var text: String?
    var imagePath: String?
    var isFrontMatter: Bool
}

private struct EchoEPUBBlockParser {
    let rootURL: URL

    func parse() throws -> [EchoEPUBBlock] {
        let resolver = EPUBPathResolver(rootURL: rootURL)
        let containerURL = try resolver.resolveEPUBPath("META-INF/container.xml", relativeTo: rootURL)
        let containerData = try Data(contentsOf: containerURL)
        guard let opfRelativePath = EchoContainerXMLParser.packagePath(from: containerData) else {
            throw EPUBExtractionError.containerMissingRootfile
        }

        let opfURL = try resolver.resolveEPUBPath(opfRelativePath, relativeTo: rootURL)
        let opfDirectory = opfURL.deletingLastPathComponent()
        let opfData = try Data(contentsOf: opfURL)
        let opfResult = EchoOPFParser.parse(opfData)
        let spine = opfResult.spine
        guard !spine.isEmpty else {
            throw EPUBExtractionError.packageMissingSpine
        }

        var tocMap: [String: String] = [:]
        var landmarks: [EchoGuideReference] = []
        if let tocHref = opfResult.tocHref,
           let tocURL = try? Self.resolveEPUBHref(
            tocHref,
            rootURL: rootURL,
            baseURL: opfDirectory
           ),
           let tocData = try? Data(contentsOf: tocURL) {
            let tocParser = EchoTOCParser()
            tocParser.parse(tocData)
            tocMap = tocParser.tocMap
            landmarks = tocParser.landmarks
        }

        let bodyStartSpineIndex = EchoEPUBStructure.bodyMatterStartIndex(
            spine: spine,
            guideReferences: opfResult.guideReferences,
            landmarks: landmarks
        )

        var parsedSpines: [(blocks: [EchoTextBlockDescriptor], title: String?)] = []
        parsedSpines.reserveCapacity(spine.count)

        for item in spine {
            let xhtmlURL = try Self.resolveEPUBHref(
                item.href,
                rootURL: rootURL,
                baseURL: opfDirectory
            )
            guard FileManager.default.fileExists(atPath: xhtmlURL.path) else {
                parsedSpines.append((blocks: [], title: nil))
                continue
            }

            let xhtmlData = try Data(contentsOf: xhtmlURL)
            parsedSpines.append(EchoXHTMLParser.parse(xhtmlData))
        }

        var engine = EchoEPUBHeuristicEngine(
            tocLabels: Array(tocMap.values),
            spineItemCount: spine.count
        )
        engine.buildCSSFingerprint(from: parsedSpines.flatMap(\.blocks))

        var blocks: [EchoEPUBBlock] = []
        var sequenceIndex = 0
        var hasSeenContentHeading = false

        for spineIndex in parsedSpines.indices {
            var textBlocks = parsedSpines[spineIndex].blocks
            let spineHref = spine[spineIndex].href

            for blockIndex in textBlocks.indices {
                let newKind = engine.score(block: textBlocks[blockIndex])
                textBlocks[blockIndex].kind = newKind
            }

            let hasContentHeading = textBlocks.contains { block in
                guard block.kind == .heading,
                      let text = block.text,
                      !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return false
                }
                return !EchoHeadingClassifier.isJunk(text)
            }

            let decodedHref = spineHref.removingPercentEncoding ?? spineHref
            let hrefWithoutFragment = String(decodedHref.components(separatedBy: "#")[0])
            let fallbackTitle = tocMap[hrefWithoutFragment]
                ?? parsedSpines[spineIndex].title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleIsNonContent = fallbackTitle.map(EchoHeadingClassifier.isNonContent) ?? false
            let structuralFrontMatter = !spine[spineIndex].linear
                || (bodyStartSpineIndex.map { spineIndex < $0 } ?? false)
            let isFrontMatterSpine = structuralFrontMatter
                || (!hasContentHeading && titleIsNonContent && !hasSeenContentHeading)

            if hasContentHeading {
                hasSeenContentHeading = true
            } else if !isFrontMatterSpine,
                      !titleIsNonContent,
                      let title = fallbackTitle,
                      !title.isEmpty,
                      title.lowercased() != "untitled",
                      title.lowercased() != "unknown" {
                textBlocks.insert(
                    EchoTextBlockDescriptor(
                        kind: .heading,
                        text: title,
                        imagePath: nil,
                        rawClasses: [],
                        rawTags: "h2",
                        anchorIDs: []
                    ),
                    at: 0
                )
            }

            for (blockIndex, textBlock) in textBlocks.enumerated() {
                blocks.append(
                    EchoEPUBBlock(
                        id: "epub-builder-s\(spineIndex)-b\(blockIndex)",
                        spineHref: spineHref,
                        spineIndex: spineIndex,
                        blockIndex: blockIndex,
                        sequenceIndex: sequenceIndex,
                        kind: textBlock.kind,
                        text: textBlock.text,
                        imagePath: textBlock.imagePath,
                        isFrontMatter: isFrontMatterSpine
                    )
                )
                sequenceIndex += 1
            }
        }

        return blocks
    }

    private static func resolveEPUBHref(_ href: String, rootURL: URL, baseURL: URL) throws -> URL {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return try EPUBPathResolver(rootURL: rootURL)
                .resolveEPUBPath(String(trimmed.dropFirst()), relativeTo: rootURL)
        }
        return try EPUBPathResolver(rootURL: rootURL)
            .resolveEPUBPath(trimmed, relativeTo: baseURL)
    }
}

private struct EchoSpineItem: Sendable {
    let id: String
    let href: String
    let mediaType: String
    let linear: Bool
}

private struct EchoGuideReference: Sendable {
    let type: String
    let href: String
}

private struct EchoOPFParseResult: Sendable {
    let spine: [EchoSpineItem]
    let tocHref: String?
    let guideReferences: [EchoGuideReference]
}

private struct EchoTextBlockDescriptor: Sendable {
    var kind: EchoEPUBBlock.Kind
    var text: String?
    let imagePath: String?
    let rawClasses: [String]
    let rawTags: String
    let anchorIDs: [String]
}

private enum EchoContainerXMLParser {
    static func packagePath(from data: Data) -> String? {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        parser.parse()
        return delegate.rootfilePath
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var rootfilePath: String?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            if elementName == "rootfile", let path = attributeDict["full-path"] {
                rootfilePath = path
            }
        }
    }
}

private enum EchoOPFParser {
    static func parse(_ data: Data) -> EchoOPFParseResult {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.parse()
        return EchoOPFParseResult(
            spine: delegate.spineItems,
            tocHref: delegate.tocHref,
            guideReferences: delegate.guideReferences
        )
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var spineItems: [EchoSpineItem] = []
        var tocHref: String? { navHref ?? ncxHref }
        var guideReferences: [EchoGuideReference] = []
        private var navHref: String?
        private var ncxHref: String?
        private var manifestItems: [String: EchoSpineItem] = [:]
        private var spineRefs: [(idref: String, linear: Bool)] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "itemref":
                if let idref = attributeDict["idref"] {
                    spineRefs.append((idref: idref, linear: attributeDict["linear"]?.lowercased() != "no"))
                }
            case "reference":
                if let type = attributeDict["type"], let href = attributeDict["href"] {
                    guideReferences.append(EchoGuideReference(type: type, href: href))
                }
            case "item":
                guard let id = attributeDict["id"],
                      let href = attributeDict["href"],
                      let mediaType = attributeDict["media-type"] else {
                    return
                }
                manifestItems[id] = EchoSpineItem(
                    id: id,
                    href: href,
                    mediaType: mediaType,
                    linear: true
                )

                let properties = (attributeDict["properties"] ?? "").split(separator: " ")
                if properties.contains("nav") {
                    navHref = href
                } else if id == "ncx" || mediaType == "application/x-dtbncx+xml" {
                    ncxHref = href
                }
            default:
                break
            }
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            spineItems = spineRefs.compactMap { ref in
                guard let item = manifestItems[ref.idref] else { return nil }
                return EchoSpineItem(
                    id: item.id,
                    href: item.href,
                    mediaType: item.mediaType,
                    linear: ref.linear
                )
            }
        }
    }
}

private final class EchoTOCParser: NSObject, XMLParserDelegate {
    var tocMap: [String: String] = [:]
    var landmarks: [EchoGuideReference] = []
    private var isInsideNavLabelText = false
    private var currentText = ""
    private var currentSrc = ""
    private var navTypes: [String] = []

    func parse(_ data: Data) {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "nav":
            navTypes.append(attributeDict["epub:type"] ?? "")
        case "text":
            isInsideNavLabelText = true
            currentText = ""
        case "content":
            if let src = attributeDict["src"] {
                currentSrc = src
                let label = currentText.echoCollapsedWhitespace()
                if !label.isEmpty {
                    let href = String(currentSrc.components(separatedBy: "#")[0])
                    let decodedHref = href.removingPercentEncoding ?? href
                    if tocMap[decodedHref] == nil {
                        tocMap[decodedHref] = label
                    }
                }
            }
        case "a":
            guard let href = attributeDict["href"] else { return }
            let navWords = (navTypes.last ?? "").split(separator: " ")
            if navWords.contains("landmarks") {
                let cleanHref = String(href.components(separatedBy: "#")[0])
                let decoded = cleanHref.removingPercentEncoding ?? cleanHref
                landmarks.append(EchoGuideReference(type: attributeDict["epub:type"] ?? "", href: decoded))
            } else if navWords.isEmpty || navWords.contains("toc") {
                currentSrc = href
                isInsideNavLabelText = true
                currentText = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideNavLabelText {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "nav":
            if !navTypes.isEmpty {
                navTypes.removeLast()
            }
        case "text":
            isInsideNavLabelText = false
        case "a":
            guard isInsideNavLabelText else { return }
            isInsideNavLabelText = false
            let href = String(currentSrc.components(separatedBy: "#")[0])
            let decodedHref = href.removingPercentEncoding ?? href
            let label = currentText.echoCollapsedWhitespace()
            if tocMap[decodedHref] == nil, !label.isEmpty {
                tocMap[decodedHref] = label
            }
        default:
            break
        }
    }
}

private enum EchoXHTMLParser {
    static func parse(_ data: Data) -> (blocks: [EchoTextBlockDescriptor], title: String?) {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        parser.parse()
        delegate.flushBlock()
        return (delegate.textBlocks, delegate.documentTitle?.echoCollapsedWhitespace())
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var textBlocks: [EchoTextBlockDescriptor] = []
        var documentTitle: String?
        private var currentText = ""
        private var currentHeading = ""
        private var isInBlock = false
        private var isInHeading = false
        private var skipDepth = 0
        private var isInsideHead = false
        private var isInsideTitle = false
        private var currentBlockClasses: [String] = []
        private var currentBlockTags = ""
        private var pendingAnchorIDs: [String] = []

        private let skipTags: Set<String> = ["script", "style", "figcaption"]
        private let blockTags: Set<String> = [
            "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "li", "section"
        ]
        private let inlineTags: Set<String> = [
            "b", "i", "em", "strong", "span", "small", "sub", "sup", "a", "br", "u"
        ]

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let elementName = elementName.lowercased()
            if skipTags.contains(elementName) {
                skipDepth += 1
                return
            }
            guard skipDepth == 0 else { return }

            if elementName == "head" {
                isInsideHead = true
                return
            }
            if elementName == "title" {
                isInsideTitle = true
                return
            }

            insertSoftWordBreakIfStructural(elementName)

            let anchorID = attributeDict["id"]
            let flushesBlock = elementName == "img" || blockTags.contains(elementName)
            if !flushesBlock {
                captureAnchorID(anchorID)
            }

            if Self.headingTags.contains(elementName) {
                flushBlock()
                captureAnchorID(anchorID)
                isInHeading = true
                isInBlock = true
                currentHeading = ""
                currentBlockTags = elementName
                currentBlockClasses = Self.classNames(from: attributeDict["class"])
            } else if elementName == "img", let src = attributeDict["src"] {
                flushBlock()
                captureAnchorID(anchorID)
                textBlocks.append(
                    EchoTextBlockDescriptor(
                        kind: .image,
                        text: nil,
                        imagePath: src,
                        rawClasses: Self.classNames(from: attributeDict["class"]),
                        rawTags: "img",
                        anchorIDs: pendingAnchorIDs
                    )
                )
                pendingAnchorIDs = []
            } else if blockTags.contains(elementName) {
                flushBlock()
                captureAnchorID(anchorID)
                isInBlock = true
                currentBlockTags = elementName
                currentBlockClasses = Self.classNames(from: attributeDict["class"])
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard skipDepth == 0 else { return }

            if isInsideTitle {
                documentTitle = (documentTitle ?? "") + string
                return
            }
            if isInsideHead {
                return
            }

            if isInHeading {
                appendCollapsed(string, to: &currentHeading)
            }
            appendCollapsed(string, to: &currentText)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let elementName = elementName.lowercased()
            if skipTags.contains(elementName) {
                skipDepth = max(0, skipDepth - 1)
                return
            }
            guard skipDepth == 0 else { return }

            if elementName == "head" {
                isInsideHead = false
                return
            }
            if elementName == "title" {
                isInsideTitle = false
                return
            }

            insertSoftWordBreakIfStructural(elementName)

            if Self.headingTags.contains(elementName) {
                isInHeading = false
                isInBlock = false
                let heading = currentHeading.trimmingCharacters(in: .whitespaces)
                currentText = ""
                if !heading.isEmpty {
                    textBlocks.append(
                        EchoTextBlockDescriptor(
                            kind: .heading,
                            text: heading,
                            imagePath: nil,
                            rawClasses: currentBlockClasses,
                            rawTags: currentBlockTags,
                            anchorIDs: pendingAnchorIDs
                        )
                    )
                    pendingAnchorIDs = []
                }
            }
        }

        fileprivate func flushBlock() {
            let text = currentText.trimmingCharacters(in: .whitespaces)
            currentText = ""
            isInBlock = false
            guard !text.isEmpty else {
                return
            }

            textBlocks.append(
                EchoTextBlockDescriptor(
                    kind: .paragraph,
                    text: text,
                    imagePath: nil,
                    rawClasses: currentBlockClasses,
                    rawTags: currentBlockTags,
                    anchorIDs: pendingAnchorIDs
                )
            )
            pendingAnchorIDs = []
            currentBlockClasses = []
            currentBlockTags = ""
        }

        private func insertSoftWordBreakIfStructural(_ elementName: String) {
            guard elementName == "br" || !inlineTags.contains(elementName) else { return }
            guard !isInsideHead else { return }
            if isInHeading {
                appendCollapsed(" ", to: &currentHeading)
            }
            appendCollapsed(" ", to: &currentText)
        }

        private func captureAnchorID(_ id: String?) {
            guard let id, !id.isEmpty else { return }
            pendingAnchorIDs.append(id)
        }

        @discardableResult
        private func appendCollapsed(_ chunk: String, to target: inout String) -> Int {
            var appended = 0
            for character in chunk {
                if character.isWhitespace {
                    if !target.isEmpty && target.last != " " {
                        target.append(" ")
                        appended += 1
                    }
                } else {
                    target.append(character)
                    appended += 1
                }
            }
            return appended
        }

        private static let headingTags: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]

        private static func classNames(from value: String?) -> [String] {
            (value ?? "").split(separator: " ").map(String.init)
        }
    }
}

private struct EchoEPUBHeuristicEngine {
    let tocLabels: [String]
    let spineItemCount: Int
    var cssFrequencyMap: [String: Int] = [:]

    mutating func buildCSSFingerprint(from blocks: [EchoTextBlockDescriptor]) {
        for block in blocks {
            let isHeading = block.rawTags.lowercased().hasPrefix("h")
            let textCount = block.text?.count ?? 0
            let isShort = textCount > 0 && textCount < 100

            if isHeading || isShort {
                for className in block.rawClasses {
                    cssFrequencyMap[className, default: 0] += 1
                }
            }
        }
    }

    func score(block: EchoTextBlockDescriptor) -> EchoEPUBBlock.Kind {
        guard block.kind == .paragraph || block.kind == .heading else {
            return block.kind
        }

        let cleanText = block.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if cleanText.isEmpty {
            return .paragraph
        }

        var score = 0
        if tocLabels.contains(where: { $0.caseInsensitiveCompare(cleanText) == .orderedSame }) {
            score += 100
        }

        let tag = block.rawTags.lowercased()
        if tag == "h1" || tag == "h2" {
            score += 90
        } else if tag.hasPrefix("h") && tag.count == 2 {
            score += 70
        }

        if cleanText.range(
            of: "^(?:chapter|part)\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            score += 70
        }

        for className in block.rawClasses {
            if let count = cssFrequencyMap[className],
               count > 0,
               count <= (spineItemCount + 5) {
                score += 60
                break
            }
        }

        if cleanText == cleanText.uppercased(),
           cleanText.count > 3,
           cleanText.rangeOfCharacter(from: .letters) != nil {
            score += 20
        }

        if cleanText.count < 60 {
            score += 15
        }

        return score >= 80 ? .heading : .paragraph
    }
}

private enum EchoHeadingClassifier {
    static func isUtilityCallout(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return ["tip", "warning", "note", "caution", "important"].contains(lower)
    }

    static func isFigureCaption(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return lower.hasPrefix("figure ") || lower.hasPrefix("table ") || lower.hasPrefix("image ")
    }

    static func isNonContent(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        let nonContentExact: Set<String> = [
            "cover", "back cover", "cover page",
            "title page", "title", "half title", "half-title",
            "copyright", "copyright page", "colophon",
            "dedication", "dedications", "epigraph",
            "contents", "table of contents", "toc",
            "also by", "also by the author", "also available",
            "praise for", "praise", "coming soon",
            "about the publisher", "credits",
            "list of illustrations", "list of figures", "list of tables",
            "cast of characters", "maps", "timeline",
            "front matter", "frontmatter",
            "bibliography", "references", "index", "glossary",
            "endnotes", "notes", "footnotes",
            "about the author", "about the authors",
        ]

        if nonContentExact.contains(lower) {
            return true
        }

        for prefix in [
            "also by ", "praise for ", "excerpt from ", "excerpt: ",
            "about the author", "about the publisher",
        ] where lower.hasPrefix(prefix) {
            return true
        }

        return false
    }

    static func isJunk(_ text: String) -> Bool {
        text.count > 100
            || isUtilityCallout(text)
            || isFigureCaption(text)
            || isNonContent(text)
    }
}

private enum EchoEPUBStructure {
    static func bodyMatterStartIndex(
        spine: [EchoSpineItem],
        guideReferences: [EchoGuideReference],
        landmarks: [EchoGuideReference]
    ) -> Int? {
        let candidates = landmarks.filter {
            $0.type.split(separator: " ").contains("bodymatter")
        } + guideReferences.filter {
            $0.type == "text"
        }

        for candidate in candidates {
            if let index = spineIndex(of: candidate.href, in: spine) {
                return index
            }
        }
        return nil
    }

    private static func spineIndex(of href: String, in spine: [EchoSpineItem]) -> Int? {
        let target = normalizeHref(href)
        if let exact = spine.firstIndex(where: { normalizeHref($0.href) == target }) {
            return exact
        }
        let targetName = URL(fileURLWithPath: target).lastPathComponent
        return spine.firstIndex {
            URL(fileURLWithPath: normalizeHref($0.href)).lastPathComponent == targetName
        }
    }

    private static func normalizeHref(_ href: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        return String(decoded.components(separatedBy: "#")[0])
    }
}

private extension StringProtocol {
    func echoCollapsedWhitespace() -> String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
