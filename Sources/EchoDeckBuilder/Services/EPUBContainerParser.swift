import Foundation

public final class EPUBContainerParser: NSObject, XMLParserDelegate {
    private var rootfilePath: String?

    public override init() {
        super.init()
    }

    public func packagePath(from data: Data) throws -> String {
        rootfilePath = nil
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw EPUBExtractionError.containerParseFailed(
                parser.parserError?.localizedDescription ?? "Unknown XML parse error"
            )
        }

        guard let rootfilePath, !rootfilePath.isEmpty else {
            throw EPUBExtractionError.containerMissingRootfile
        }
        return rootfilePath
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName.lowercased() == "rootfile" {
            rootfilePath = attributeDict["full-path"]
        }
    }
}
