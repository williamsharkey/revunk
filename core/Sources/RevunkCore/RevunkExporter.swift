import Foundation
import AVFoundation
import CoreMedia

public enum RevunkExporter {
    public static func export(path: String) throws {
        let inputURL = URL(fileURLWithPath: path)
        let text = try String(contentsOf: inputURL)

        let parser = RevunkTextParser()
        let project = try parser.parse(text)

        guard let videoRef = project.video else {
            throw NSError(domain: "revunk", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video specified"])
        }
        guard let bpm = project.bpm else {
            throw NSError(domain: "revunk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing bpm"])
        }

        let sourceURL = URL(fileURLWithPath: videoRef)
        let asset = AVAsset(url: sourceURL)

        guard let srcVideo = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "revunk", code: 3, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }
        let srcAudio = asset.tracks(withMediaType: .audio).first

        // -------- Frame-native timing --------
        let fps: Int32 = 30
        let frameDuration = CMTime(value: 1, timescale: fps)

        let secondsPerBeat = 60.0 / bpm
        let framesPerBeat = Int(round(secondsPerBeat * Double(fps)))
        let beatDuration = CMTime(value: Int64(framesPerBeat), timescale: fps)

        let rawFadeSeconds = project.defaultCrossfade?.duration ?? 0
        let rawFadeFrames = Int(round(rawFadeSeconds * Double(fps)))
        let maxFadeFrames = Int(round(Double(framesPerBeat) * 0.45))
        let fadeFrames = max(0, min(rawFadeFrames, maxFadeFrames))
        let fadeDuration = CMTime(value: Int64(fadeFrames), timescale: fps)

        func t(_ frames: Int) -> CMTime {
            CMTime(value: Int64(frames), timescale: fps)
        }

        // -------- Composition --------
        let composition = AVMutableComposition()

        let baseVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let overlayVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let srcTransform = srcVideo.preferredTransform

        var cursorFrames = 0

        // Populate baseVideoTrack contiguously and handle audio
        for (idx, edit) in project.exportBeats.enumerated() {
            let sourceStartSeconds = Double(edit.beat - 1) * secondsPerBeat
            let sourceStartFrames = Int(round(sourceStartSeconds * Double(fps)))
            let srcRange = CMTimeRange(start: t(sourceStartFrames), duration: beatDuration)

            try baseVideoTrack?.insertTimeRange(srcRange, of: srcVideo, at: t(cursorFrames))

            if let sa = srcAudio, let ca = audioTrack {
                try ca.insertTimeRange(srcRange, of: sa, at: t(cursorFrames))
            }
            cursorFrames += framesPerBeat
        }

        var instructions: [AVMutableVideoCompositionInstruction] = []
        cursorFrames = 0 // Reset cursor for instruction generation

        // Generate instructions for video composition
        for (idx, edit) in project.exportBeats.enumerated() {
            let instructionTimeRange = CMTimeRange(start: t(cursorFrames), duration: beatDuration)
            let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
            videoCompositionInstruction.timeRange = instructionTimeRange

            if edit.transitionToNext == .crossfade && fadeFrames > 0 && idx + 1 < project.exportBeats.count {
                let nextEdit = project.exportBeats[idx + 1]
                let nextSourceStartSeconds = Double(nextEdit.beat - 1) * secondsPerBeat
                let nextSourceStartFrames = Int(round(nextSourceStartSeconds * Double(fps)))
                let overlapStartFrames = cursorFrames + framesPerBeat - fadeFrames

                // Insert the next beat's video into the overlay track for the crossfade
                try overlayVideoTrack?.insertTimeRange(
                    CMTimeRange(start: t(nextSourceStartFrames), duration: beatDuration),
                    of: srcVideo,
                    at: t(overlapStartFrames)
                )

                let baseLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: baseVideoTrack!)
                baseLayerInstruction.setTransform(srcTransform, at: .zero)
                baseLayerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange(start: t(overlapStartFrames), duration: fadeDuration))

                let overlayLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: overlayVideoTrack!)
                overlayLayerInstruction.setTransform(srcTransform, at: .zero)
                overlayLayerInstruction.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: CMTimeRange(start: t(overlapStartFrames), duration: fadeDuration))

                videoCompositionInstruction.layerInstructions = [baseLayerInstruction, overlayLayerInstruction]
            } else {
                let baseLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: baseVideoTrack!)
                baseLayerInstruction.setTransform(srcTransform, at: .zero)
                videoCompositionInstruction.layerInstructions = [baseLayerInstruction]
            }

            instructions.append(videoCompositionInstruction)
            cursorFrames += framesPerBeat
        }

        // Sort instructions by time (required)
        instructions.sort { CMTimeCompare($0.timeRange.start, $1.timeRange.start) < 0 }

        // -------- Export --------
        var baseURL = inputURL
        if baseURL.pathExtension == "txt" { baseURL = baseURL.deletingPathExtension() }
        if baseURL.pathExtension == "revunk" || baseURL.pathExtension == "revunk" {
            baseURL = baseURL.deletingPathExtension()
        }
        let outputURL = baseURL.appendingPathExtension("revunk.out.mp4")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = srcVideo.naturalSize
        videoComposition.frameDuration = frameDuration
        videoComposition.instructions = instructions

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "revunk", code: 4)
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = videoComposition

        let sem = DispatchSemaphore(value: 0)
        exporter.exportAsynchronously { sem.signal() }
        sem.wait()
        if exporter.status != .completed {
            throw exporter.error ?? NSError(domain: "revunk", code: 5)
        }

        let fingerprint = try SourceFingerprint(originalName: sourceURL.lastPathComponent, fileURL: sourceURL)
        let metadata = MetadataRevunk(projectText: text, sources: [fingerprint])
        let metaURL = outputURL.deletingPathExtension().appendingPathExtension("metadata.revunk.txt")
        try metadata.asText().write(to: metaURL, atomically: true, encoding: .utf8)
    }
}
