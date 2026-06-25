import Foundation

public struct EPUBArchiveExtractor: Sendable {
    public init() {}

    public func extract(epubURL: URL) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilder", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try validateArchiveEntryPaths(in: epubURL)
            try unzip(epubURL: epubURL, to: destination)
            try validateExtractedContents(at: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private func validateArchiveEntryPaths(in epubURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", epubURL.path]

        let outputFiles = try ProcessOutputFiles()
        defer { outputFiles.cleanup() }

        let standardOutput = try FileHandle(forWritingTo: outputFiles.standardOutputURL)
        let standardError = try FileHandle(forWritingTo: outputFiles.standardErrorURL)
        defer {
            try? standardOutput.close()
            try? standardError.close()
        }

        process.standardOutput = standardOutput
        process.standardError = standardError

        try run(process: process, standardErrorURL: outputFiles.standardErrorURL)
        let data = try Data(contentsOf: outputFiles.standardOutputURL)
        let output = String(data: data, encoding: .utf8) ?? ""
        let paths = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for path in paths where !path.isEmpty {
            try EPUBPathResolver.validateArchiveEntryPath(path)
        }
    }

    private func unzip(epubURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", epubURL.path, "-d", destination.path]

        let outputFiles = try ProcessOutputFiles()
        defer { outputFiles.cleanup() }

        let standardError = try FileHandle(forWritingTo: outputFiles.standardErrorURL)
        defer { try? standardError.close() }

        process.standardError = standardError

        try run(process: process, standardErrorURL: outputFiles.standardErrorURL)
    }

    private func validateExtractedContents(at destination: URL) throws {
        let resolver = EPUBPathResolver(rootURL: destination)
        let keys: [URLResourceKey] = [.isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: destination,
            includingPropertiesForKeys: keys
        ) else {
            return
        }

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                throw EPUBExtractionError.invalidArchiveEntryPath(url.lastPathComponent)
            }

            guard resolver.contains(url) else {
                throw EPUBExtractionError.invalidArchiveEntryPath(url.path)
            }
        }
    }

    private func run(process: Process, standardErrorURL: URL) throws {
        do {
            try process.run()
        } catch {
            throw EPUBExtractionError.unzipFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = (try? Data(contentsOf: standardErrorURL)) ?? Data()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "unzip exited with \(process.terminationStatus)"
            throw EPUBExtractionError.unzipFailed(message)
        }
    }
}

private struct ProcessOutputFiles {
    let standardOutputURL: URL
    let standardErrorURL: URL

    init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilderProcessOutput", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        standardOutputURL = directory.appendingPathComponent("stdout.txt")
        standardErrorURL = directory.appendingPathComponent("stderr.txt")

        FileManager.default.createFile(atPath: standardOutputURL.path, contents: nil)
        FileManager.default.createFile(atPath: standardErrorURL.path, contents: nil)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: standardOutputURL.deletingLastPathComponent())
    }
}
