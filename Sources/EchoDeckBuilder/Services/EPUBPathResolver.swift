import Foundation

public struct EPUBPathResolver: Sendable {
    private let rootURL: URL
    private let rootPath: String

    public init(rootURL: URL) {
        self.rootURL = Self.canonicalDirectoryURL(rootURL)
        self.rootPath = self.rootURL.path
    }

    public func resolveEPUBPath(_ rawPath: String, relativeTo baseURL: URL) throws -> URL {
        let decodedPath = try Self.decodedRelativePath(fromURI: rawPath)
        let baseURL = Self.canonicalDirectoryURL(baseURL)
        let resolvedURL = URL(fileURLWithPath: decodedPath, relativeTo: baseURL)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        guard contains(resolvedURL) else {
            throw EPUBExtractionError.invalidEPUBPath(rawPath)
        }

        return resolvedURL
    }

    public func contains(_ url: URL) -> Bool {
        let resolvedPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        return resolvedPath == rootPath || resolvedPath.hasPrefix(rootPath + "/")
    }

    public static func validateArchiveEntryPath(_ rawPath: String) throws {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw EPUBExtractionError.invalidArchiveEntryPath(rawPath)
        }

        guard !path.hasPrefix("/"), !path.hasPrefix("\\"), !path.contains("\\") else {
            throw EPUBExtractionError.invalidArchiveEntryPath(rawPath)
        }

        let trimmedDirectorySuffix = String(path.dropLast(path.hasSuffix("/") ? 1 : 0))
        let components = trimmedDirectorySuffix.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else {
            throw EPUBExtractionError.invalidArchiveEntryPath(rawPath)
        }

        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw EPUBExtractionError.invalidArchiveEntryPath(rawPath)
        }
    }

    public static func decodedRelativePath(fromURI rawURI: String) throws -> String {
        try decodedRelativePathComponents(fromURI: rawURI).joined(separator: "/")
    }

    private static func decodedRelativePathComponents(fromURI rawURI: String) throws -> [String] {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EPUBExtractionError.invalidEPUBPath(rawURI)
        }

        let fragmentless = trimmed.split(
            separator: "#",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).first.map(String.init) ?? ""
        let queryless = fragmentless.split(
            separator: "?",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).first.map(String.init) ?? ""

        guard !queryless.isEmpty else {
            throw EPUBExtractionError.invalidEPUBPath(rawURI)
        }

        if let components = URLComponents(string: queryless) {
            guard components.scheme == nil, components.host == nil, components.user == nil, components.password == nil else {
                throw EPUBExtractionError.invalidEPUBPath(rawURI)
            }
        }

        let encodedPath = URLComponents(string: queryless)?.percentEncodedPath ?? queryless
        guard !encodedPath.hasPrefix("/"), !encodedPath.hasPrefix("\\"), !encodedPath.contains("\\") else {
            throw EPUBExtractionError.invalidEPUBPath(rawURI)
        }

        let encodedComponents = encodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard !encodedComponents.isEmpty else {
            throw EPUBExtractionError.invalidEPUBPath(rawURI)
        }

        return try encodedComponents.map { component in
            guard !component.isEmpty,
                  let decodedComponent = String(component).removingPercentEncoding,
                  !decodedComponent.isEmpty,
                  !decodedComponent.contains("/"),
                  !decodedComponent.contains("\\") else {
                throw EPUBExtractionError.invalidEPUBPath(rawURI)
            }

            return decodedComponent
        }
    }

    private static func canonicalDirectoryURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
