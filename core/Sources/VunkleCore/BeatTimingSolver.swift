import Foundation
import CoreMedia

public enum BeatAnchorKind: Equatable {
    case absolute(CMTime)
    case relative(CMTime)
}

public struct BeatAnchor: Equatable {
    public let index: Int
    public let kind: BeatAnchorKind
}

public struct BPMChange: Equatable {
    public let startBeat: Int
    public let bpm: Double
}

public struct BeatTimingSolver {
    public let downbeat: CMTime
    public let baseBPM: Double
    public let anchors: [BeatAnchor]
    public let tempoChanges: [BPMChange]

    public init(
        downbeat: CMTime,
        bpm: Double,
        anchors: [BeatAnchor] = [],
        tempoChanges: [BPMChange] = []
    ) {
        self.downbeat = downbeat
        self.baseBPM = bpm
        self.anchors = anchors.sorted { $0.index < $1.index }
        self.tempoChanges = tempoChanges.sorted { $0.startBeat < $1.startBeat }
    }

    public func time(for beat: Int) -> CMTime {
        // Absolute anchor wins
        if let a = anchors.first(where: { $0.index == beat }) {
            switch a.kind {
            case .absolute(let t):
                return t
            case .relative(let dt):
                return baseTime(for: beat) + dt
            }
        }
        return baseTime(for: beat)
    }

    private func baseTime(for beat: Int) -> CMTime {
        // Nearest absolute anchor on either side
        let prevAbs = anchors.last(where: {
            $0.index < beat && isAbsolute($0)
        })
        let nextAbs = anchors.first(where: {
            $0.index > beat && isAbsolute($0)
        })

        let bpm = bpm(at: beat)
        let spb = 60.0 / bpm
        let spbTime = CMTime(seconds: spb, preferredTimescale: 600)

        if let p = prevAbs, case .absolute(let t) = p.kind {
            let delta = beat - p.index
            return t + spbTime * CMTime(value: Int64(delta), timescale: 1)
        }

        if let n = nextAbs, case .absolute(let t) = n.kind {
            let delta = n.index - beat
            return t - spbTime * CMTime(value: Int64(delta), timescale: 1)
        }

        let delta = beat - 1
        return downbeat + spbTime * CMTime(value: Int64(delta), timescale: 1)
    }

    private func bpm(at beat: Int) -> Double {
        tempoChanges.last(where: { $0.startBeat <= beat })?.bpm ?? baseBPM
    }

    private func isAbsolute(_ a: BeatAnchor) -> Bool {
        if case .absolute = a.kind { return true }
        return false
    }
}
