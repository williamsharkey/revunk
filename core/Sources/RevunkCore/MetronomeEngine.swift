import Foundation
import AVFoundation

public final class MetronomeEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let clickBuffer: AVAudioPCMBuffer

    public init(sampleRate: Double = 44100.0, clickFrequency: Double = 2000.0, duration: Double = 0.01) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        clickBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        clickBuffer.frameLength = frameCount
        let theta = 2.0 * Double.pi * clickFrequency / sampleRate
        for i in 0..<Int(frameCount) {
            let v = sin(theta * Double(i)) * exp(-Double(i) / (sampleRate * duration))
            clickBuffer.floatChannelData![0][i] = Float(v)
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    public func schedule(beats: [CMTime], volume: Float = 0.6) {
        player.volume = volume
        let start = AVAudioTime(hostTime: mach_absolute_time())
        for t in beats {
            let seconds = t.seconds
            let when = AVAudioTime(hostTime: start.hostTime + AVAudioTime.hostTime(forSeconds: seconds))
            player.scheduleBuffer(clickBuffer, at: when, options: [])
        }
        player.play()
    }

    public func stop() {
        player.stop()
        engine.stop()
    }
}
