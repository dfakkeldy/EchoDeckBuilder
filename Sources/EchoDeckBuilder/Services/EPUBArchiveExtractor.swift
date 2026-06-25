import Foundation

public struct EPUBArchiveExtractor: Sendable {
    public init() {}

    public func extract(epubURL: URL) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoDeckBuilder", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            throw EPUBExtractionError.unzipFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", epubURL.path, "-d", destination.path]

        let standardError = Pipe()
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw EPUBExtractionError.unzipFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = standardError.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "unzip exited with \(process.terminationStatus)"
            throw EPUBExtractionError.unzipFailed(message)
        }

        return destination
    }
}
