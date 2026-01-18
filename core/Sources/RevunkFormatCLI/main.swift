import Foundation
import RevunkCore

@main
struct RevunkFormatCLI {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            fatalError("usage: revunk-format file.revunk.txt [-i]")
        }

        let path = args[1]
        let inplace = args.contains("-i")

        let input = try! String(contentsOfFile: path)
        let output = format(text: input)

        if inplace {
            try! output.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            print(output)
        }
    }

    static func format(text: String) -> String {
        var out: [String] = []
        var inExport = false
        var buffer: [[String]] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            let width = buffer.flatMap { $0 }.map { $0.count }.max() ?? 0
            for row in buffer {
                let padded = row.map { $0.padding(toLength: width, withPad: " ", startingAt: 0) }
                out.append("  " + padded.joined(separator: " "))
            }
            buffer.removeAll()
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            let trimmed = s.trimmingCharacters(in: .whitespaces)

            if trimmed == "export:" {
                flush()
                inExport = true
                out.append(s)
                continue
            }

            if inExport {
                if trimmed.isEmpty || trimmed.hasSuffix(":") {
                    flush()
                    inExport = false
                    out.append(s)
                } else {
                    let nums = s.split(whereSeparator: \ .isWhitespace).map(String.init)
                    buffer.append(nums)
                }
                continue
            }

            out.append(s)
        }

        flush()
        return out.joined(separator: "\n")
    }
}
