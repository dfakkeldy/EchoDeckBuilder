import Foundation

public struct EPUBSpineItem: Hashable, Sendable {
    public let spineIndex: Int
    public let href: String
    public let fileURL: URL

    public init(spineIndex: Int, href: String, fileURL: URL) {
        self.spineIndex = spineIndex
        self.href = href
        self.fileURL = fileURL
    }
}

public final class EPUBManifestParser: NSObject, XMLParserDelegate {
    private var manifest: [String: String] = [:]
    private var spineIDRefs: [String] = []

    public override init() {
        super.init()
    }

    public func spineItems(fromPackageData data: Data, packageDirectory: URL) throws -> [EPUBSpineItem] {
        manifest = [:]
        spineIDRefs = []

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw EPUBExtractionError.packageMissingSpine
        }

        guard !spineIDRefs.isEmpty else {
            throw EPUBExtractionError.packageMissingSpine
        }

        return try spineIDRefs.enumerated().map { offset, idref in
            guard let href = manifest[idref] else {
                throw EPUBExtractionError.manifestItemMissing(idref)
            }

            return EPUBSpineItem(
                spineIndex: offset + 1,
                href: href,
                fileURL: try EPUBPathResolver(rootURL: packageDirectory)
                    .resolveEPUBPath(href, relativeTo: packageDirectory)
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
        switch elementName.lowercased() {
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = href
            }
        case "itemref":
            if let idref = attributeDict["idref"] {
                spineIDRefs.append(idref)
            }
        default:
            break
        }
    }
}
