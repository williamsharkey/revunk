import Foundation
import AVFoundation

public struct WaveformSlice {
    public let timeRange: CMTimeRange
    public let samples: [Float]
    public let sampleRate: Double
}

public final class WaveformZoom {
    private let asset: AVAsset
    private let audioTrack: AVAssetTrack

    public init(asset: AVAsset) throws {
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "WaveformZoom", code: 1)
        }
        self.asset = asset
        self.audioTrack = track
    }

    public func readAround(
        center: CMTime,
        window: CMTime,
        maxSamples: Int = 8192
    ) async throws -> WaveformSlice {
        let half = CMTimeMultiplyByFloat64(window, multiplier: 0.5)
        let start = max(.zero, center - half)
        let range = CMTimeRange(start: start, duration: window)

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.timeRange = range
        reader.startReading()

        var collected: [Float] = []
        var sampleRate: Double = 44100

        while reader.status == .reading {
            guard let sbuf = output.copyNextSampleBuffer(),
                  let bbuf = CMSampleBufferGetDataBuffer(sbuf) else { break }
            var length = 0
            var dataPtr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(bbuf, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPtr)
            if let fmt = CMSampleBufferGetFormatDescription(sbuf),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) {
                sampleRate = asbd.pointee.mSampleRate
            }
            let count = length / MemoryLayout<Float>.size
            let floats = dataPtr!.withMemoryRebound(to: Float.self, capacity: count) {
                Array(UnsafeBufferPointer(start: $0, count: count))
            }
            collected.append(contentsOf: floats)
            if collected.count >= maxSamples { break }
        }

        if collected.count > maxSamples {
            collected = Array(collected.prefix(maxSamples))
        }

        return WaveformSlice(timeRange: range, samples: collected, sampleRate: sampleRate)
    }
}
