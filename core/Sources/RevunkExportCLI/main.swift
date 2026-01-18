import Foundation
import AVFoundation
import RevunkCore

@main
struct RevunkExportCLI {
    static func main() async {
        guard CommandLine.arguments.count >= 2 else {
            fatalError("usage: revunk-export edit.revunk.txt")
        }

        let editURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let baseDir = editURL.deletingLastPathComponent()
        let text = (try? String(contentsOf: editURL)) ?? ""

        let parser = RevunkTextParser()
        let file = try! parser.parse(text)

        guard let videoName = file.video,
              let downbeat = file.downbeat,
              let bpm = file.bpm
        else { fatalError("missing required fields") }

        let videoURL = baseDir.appendingPathComponent(videoName)
        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        guard let srcVideo = asset.tracks(withMediaType: .video).first,
              let srcAudio = asset.tracks(withMediaType: .audio).first
        else { fatalError("missing tracks") }

        let composition = AVMutableComposition()
        let dstVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let dstAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!

        let solver = BeatTimingSolver(
            downbeat: downbeat,
            bpm: bpm,
            anchors: file.anchors,
            tempoChanges: file.tempoChanges
        )

        var cursor = CMTime.zero
        let mix = AVMutableAudioMix()
        var params: [AVMutableAudioMixInputParameters] = []

        for (i, edit) in file.exportBeats.enumerated() {
            let start = solver.time(for: edit.beat)
            let end = solver.time(for: edit.beat + 1)
            let duration = end - start
            let range = CMTimeRange(start: start, duration: duration)

            try? dstVideo.insertTimeRange(range, of: srcVideo, at: cursor)
            try? dstAudio.insertTimeRange(range, of: srcAudio, at: cursor)

            if i > 0, let xf = file.defaultCrossfade {
                let maxXF = CMTimeMultiplyByFloat64(duration, multiplier: 0.5)
                let xfDur = min(CMTime(seconds: xf.duration, preferredTimescale: 600), maxXF)
                let p = AVMutableAudioMixInputParameters(track: dstAudio)
                p.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: cursor - xfDur, duration: xfDur))
                params.append(p)
            }

            cursor = cursor + duration
        }

        mix.inputParameters = params

        let outURL = baseDir
            .appendingPathComponent(videoURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("revunk.out.mp4")

        try? FileManager.default.removeItem(at: outURL)

        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        exporter.outputURL = outURL
        exporter.outputFileType = .mp4
        exporter.audioMix = mix

        await exporter.export()

        guard exporter.status == .completed else {
            fatalError(exporter.error?.localizedDescription ?? "export failed")
        }

        print("exported", outURL.path)
    }
}
