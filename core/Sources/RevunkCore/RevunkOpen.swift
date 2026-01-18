import Foundation

public enum RevunkOpenError: Error {
    case metadataNotFound
}

public final class RevunkOpen {
    public static func readMetadata(from url: URL) throws -> MetadataRevunk {
        // For now, expect a sidecar .metadata.revunk.txt next to export
        let metaURL = url.deletingPathExtension().appendingPathExtension("metadata.revunk.txt")
        guard FileManager.default.fileExists(atPath: metaURL.path) else {
            throw RevunkOpenError.metadataNotFound
        }
        let text = try String(contentsOf: metaURL)
        // Minimal parse: reuse MetadataRevunk textual initializer via JSON/YAML later
        // Current implementation assumes exact format written by MetadataRevunk.asText()
        // Store raw project text block only
        let projectLines = text.split(separator: "\n").drop(while: { !$0.hasPrefix("project:") }).dropFirst()
        let projectText = projectLines.map { String($0.dropFirst(2)) }.joined(separator: "\n")
        return MetadataRevunk(projectText: projectText, sources: [])
    }
}
