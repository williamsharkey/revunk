import Foundation

public struct AutoVunkOptions {
    public let startBeat: Int
    public let endBeat: Int
    public let targetBeats: Int
    public let minStride: Int

    public init(startBeat: Int, endBeat: Int, targetBeats: Int, minStride: Int) {
        self.startBeat = startBeat
        self.endBeat = endBeat
        self.targetBeats = targetBeats
        self.minStride = minStride
    }
}

public final class AutoVunkGenerator {
    public static func generate(options: AutoVunkOptions) -> [Int] {
        let total = max(0, options.endBeat - options.startBeat)
        guard total > 0 else { return [] }
        let stride = max(options.minStride, total / max(1, options.targetBeats))
        var beats: [Int] = []
        var b = options.startBeat
        while b < options.endBeat {
            beats.append(b)
            b += stride
        }
        return beats
    }
}