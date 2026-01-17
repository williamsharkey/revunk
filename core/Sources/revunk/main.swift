import Foundation
import VunkleCore

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
    try VunkleExporter.export(path: path)

case "open":
    guard let path = args.dropFirst().first else {
        print("missing export file")
        exit(1)
    }
    let meta = try VunkleOpen.readMetadata(from: URL(fileURLWithPath: path))
    let out = path + ".revunk.txt"
    try meta.projectText.write(toFile: out, atomically: true, encoding: .utf8)
    print("restored project to", out)

case "format":
    guard let path = args.dropFirst().first else {
        print("missing file")
        exit(1)
    }
    let text = try String(contentsOfFile: path)
    let formatted = VunkleFormat.format(text: text)
    print(formatted)

case "detect-grid":
    print("detect-grid not yet wired in revunk binary")

default:
    printUsage()
    exit(1)
}
