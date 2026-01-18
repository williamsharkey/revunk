import Foundation
import CoreMedia

public struct BeatAnchor: Equatable {
    public let index: Int
    public let time: CMTime
}

public struct BPMChange: Equatable {
    public let startBeat: Int
    public let bpm: Double
}

public struct Crossfade: Equatable {
    public let duration: Double
    public let audio: Bool
    public let video: Bool
}

public enum BeatTransition: Equatable {
    case cut
    case crossfade
}

public struct BeatEdit: Equatable {
    public let beat: Int
    public let transitionToNext: BeatTransition
}

public struct RevunkTextFile: Equatable {
    public var video: String?
    public var downbeat: CMTime?
    public var bpm: Double?
    public var offset: CMTime? // constant nudge applied to all beats
    public var anchors: [BeatAnchor] = []
    public var tempoChanges: [BPMChange] = []
    public var defaultCrossfade: Crossfade?
    public var exportBeats: [BeatEdit] = []
}

public enum RevunkParseError: Error {
    case invalidTime(String)
}

public final class RevunkTextParser {
    public init() {}

    public func parse(_ text: String) throws -> RevunkTextFile {
        var result = RevunkTextFile()
        var section: String? = nil

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasSuffix(":") {
                section = String(line.dropLast())
                continue
            }

            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)

                switch key {
                case "video": result.video = value
                case "bpm": result.bpm = Double(value)
                case "downbeat": result.downbeat = try Self.parseTime(value)
                case "offset": result.offset = try Self.parseTime(value)
                default: break
                }
                continue
            }

            switch section {
            case "anchor":
                let parts = line.split(separator: " ")
                if parts.count == 2,
                   let beat = Int(parts[0]) {
                    let time = try Self.parseTime(String(parts[1]))
                    result.anchors.append(.init(index: beat, time: time))
                }

            case "tempo":
                let parts = line.split(separator: " ")
                if parts.count == 2,
                   let beat = Int(parts[0]),
                   let bpm = Double(parts[1]) {
                    result.tempoChanges.append(.init(startBeat: beat, bpm: bpm))
                }

            case "crossfade":
                let parts = line.split(separator: " ")
                if parts.count == 2,
                   let duration = Double(parts[1]) {
                    let audio = parts[0] == "audio"
                    let video = parts[0] == "video"
                    let existing = result.defaultCrossfade ?? Crossfade(duration: duration, audio: false, video: false)
                    result.defaultCrossfade = Crossfade(
                        duration: duration,
                        audio: existing.audio || audio,
                        video: existing.video || video
                    )
                }

            case "export":
                for token in line.split(separator: " ") {
                    let parts = token.split(separator: "x")
                    if parts.count == 1, let beat = Int(parts[0]) {
                        result.exportBeats.append(BeatEdit(beat: beat, transitionToNext: .cut))
                    } else if parts.count == 2, let beat = Int(parts[0]), let _ = Int(parts[1]) {
                        result.exportBeats.append(.init(beat: beat, transitionToNext: .crossfade))
                    }
                }

            default:
                break
            }
        }

        return result
    }

    private static func parseTime(_ text: String) throws -> CMTime {
        let parts = text.split(separator: ":").map(String.init)
        let seconds: Double

        switch parts.count {
        case 1:
            seconds = Double(parts[0]) ?? 0
        case 2:
            seconds = (Double(parts[0]) ?? 0) * 60 + (Double(parts[1]) ?? 0)
        case 3:
            seconds = (Double(parts[0]) ?? 0) * 3600
                     + (Double(parts[1]) ?? 0) * 60
                     + (Double(parts[2]) ?? 0)
        default:
            throw RevunkParseError.invalidTime(text)
        }

        return CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
