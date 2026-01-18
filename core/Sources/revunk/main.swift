import Foundation
import RevunkCore

func printUsage() {
    print("""
    revunk — beat-first video remix engine

    usage:
      revunk export <file.revunk.txt>
      revunk open <export.revunk.out.mp4>
      revunk format <file.revunk.txt>
      revunk detect-grid <video.mp4>
    """)
}

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else {
    printUsage()
    exit(1)
}

switch command {
case "export":
    guard let path = args.dropFirst().first else {
        print("missing revunk file")
        exit(1)
    }
    try RevunkExporter.export(path: path)

case "open":
    guard let path = args.dropFirst().first else {
        print("missing export file")
        exit(1)
    }
    let meta = try RevunkOpen.readMetadata(from: URL(fileURLWithPath: path))
    var text = meta.projectText

    // Fingerprint-based source discovery
    if !meta.sources.isEmpty {
        let exportDir = URL(fileURLWithPath: path).deletingLastPathComponent()
        let searchPaths = [exportDir]
        let matches = SourceDiscovery.find(matches: meta.sources, searchPaths: searchPaths)

        if let (fp, url) = matches.first {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var resolvedLines: [String] = []
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("video:") {
                    resolvedLines.append("video: \(url.path)")
                } else {
                    resolvedLines.append(String(line))
                }
            }
            text = resolvedLines.joined(separator: "\n")
            print("relinked source using fingerprint:", fp.originalName)
        }
    }

    let out = path + ".revunk.txt"
    try text.write(toFile: out, atomically: true, encoding: .utf8)
    print("restored project to", out)

case "format":
    guard let path = args.dropFirst().first else {
        print("missing file")
        exit(1)
    }
    let text = try String(contentsOfFile: path)
    let formatted = RevunkFormat.format(text: text)
    print(formatted)

case "detect-grid":
    print("detect-grid not yet wired in revunk binary")

default:
    printUsage()
    exit(1)
}
