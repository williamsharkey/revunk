import Foundation

public struct MetadataRevunk: Codable {
    public let engine: String
    public let engineVersion: String
    public let createdAt: Date
    public let projectText: String
    public let sources: [SourceFingerprint]
    public let notes: [String]

    public init(projectText: String, sources: [SourceFingerprint], notes: [String] = []) {
        self.engine = "revunk"
        self.engineVersion = "0.x"
        self.createdAt = Date()
        self.projectText = projectText
        self.sources = sources
        self.notes = notes
    }

    public func asText() -> String {
        var lines: [String] = []
        lines.append("# metadata.revunk.txt")
        lines.append("engine: \(engine)")
        lines.append("engine-version: \(engineVersion)")
        lines.append("created-at: \(createdAt)")
        lines.append("")
        lines.append("sources:")
        for s in sources {
            lines.append("  - name: \(s.originalName)")
            lines.append("    size: \(s.fileSize)")
            lines.append(String(format: "    duration: %.3f", s.durationSeconds))
            lines.append("    sha256-prefix: \(s.sha256Prefix)")
        }
        lines.append("")
        lines.append("project:")
        for l in projectText.split(separator: "\n") {
            lines.append("  \(l)")
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append("notes:")
            for n in notes { lines.append("  - \(n)") }
        }
        return lines.joined(separator: "\n")
    }
}
