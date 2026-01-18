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
        let hasCrossfades = project.exportBeats.contains { $0.transitionToNext == .crossfade }

        let singleTrack = hasCrossfades ? nil : composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let trackA = hasCrossfades ? composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        let trackB = hasCrossfades ? composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let srcTransform = srcVideo.preferredTransform

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursorFrames = 0

        var activeTrack = trackA
        var inactiveTrack = trackB

        // -------- Main loop --------
        var i = 0
        while i < project.exportBeats.count {
            let edit = project.exportBeats[i]
            let sourceStartSeconds = Double(edit.beat - 1) * secondsPerBeat
            let sourceStartFrames = Int(round(sourceStartSeconds * Double(fps)))
            let srcRange = CMTimeRange(start: t(sourceStartFrames), duration: beatDuration)

            if let single = singleTrack {
                try single.insertTimeRange(srcRange, of: srcVideo, at: t(cursorFrames))
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: single)
                layer.setTransform(srcTransform, at: .zero)
                let instr = AVMutableVideoCompositionInstruction()
                instr.timeRange = CMTimeRange(start: t(cursorFrames), duration: beatDuration)
                instr.layerInstructions = [layer]
                instructions.append(instr)
                cursorFrames += framesPerBeat
                i += 1
                continue
            }

            guard let outTrack = activeTrack, let inTrack = inactiveTrack else { break }

            try outTrack.insertTimeRange(srcRange, of: srcVideo, at: t(cursorFrames))

            if edit.transitionToNext == .crossfade && fadeFrames > 0 && i + 1 < project.exportBeats.count {
                let nextEdit = project.exportBeats[i + 1]
                let nextSourceStartSeconds = Double(nextEdit.beat - 1) * secondsPerBeat
                let nextSourceStartFrames = Int(round(nextSourceStartSeconds * Double(fps)))
                let overlapStartFrames = cursorFrames + framesPerBeat - fadeFrames

                // Insert entire next beat contiguously on inactive track
                try inTrack.insertTimeRange(
                    CMTimeRange(start: t(nextSourceStartFrames), duration: beatDuration),
                    of: srcVideo,
                    at: t(overlapStartFrames)
                )

                // A: outgoing only
                let preDurFrames = framesPerBeat - fadeFrames
                let preLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: outTrack)
                preLayer.setTransform(srcTransform, at: .zero)
                let pre = AVMutableVideoCompositionInstruction()
                pre.timeRange = CMTimeRange(start: t(cursorFrames), duration: t(preDurFrames))
                pre.layerInstructions = [preLayer]
                instructions.append(pre)

                // B: crossfade
                let outLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: outTrack)
                let inLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: inTrack)
                outLayer.setTransform(srcTransform, at: .zero)
                inLayer.setTransform(srcTransform, at: .zero)
                let fadeRange = CMTimeRange(start: t(overlapStartFrames), duration: fadeDuration)
                outLayer.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: fadeRange)
                inLayer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: fadeRange)
                let fade = AVMutableVideoCompositionInstruction()
                fade.timeRange = fadeRange
                fade.layerInstructions = [inLayer, outLayer]
                instructions.append(fade)

                // C: incoming tail
                let postLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: inTrack)
                postLayer.setTransform(srcTransform, at: .zero)
                let post = AVMutableVideoCompositionInstruction()
                post.timeRange = CMTimeRange(start: t(cursorFrames + framesPerBeat), duration: beatDuration)
                post.layerInstructions = [postLayer]
                instructions.append(post)

                cursorFrames += framesPerBeat
                activeTrack = inTrack
                inactiveTrack = outTrack
                i += 2
            } else {
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: outTrack)
                layer.setTransform(srcTransform, at: .zero)
                let instr = AVMutableVideoCompositionInstruction()
                instr.timeRange = CMTimeRange(start: t(cursorFrames), duration: beatDuration)
                instr.layerInstructions = [layer]
                instructions.append(instr)
                cursorFrames += framesPerBeat
                i += 1
            }

            if let sa = srcAudio, let ca = audioTrack {
                try ca.insertTimeRange(srcRange, of: sa, at: t(cursorFrames))
            }
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
