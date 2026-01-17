import Foundation
import AVFoundation
import CoreMedia

public enum RevunkExporter {
    public static func export(path: String) throws {
        let inputURL = URL(fileURLWithPath: path)
        let text = try String(contentsOf: inputURL)

        let parser = VunkleTextParser()
        let project = try parser.parse(text)

        guard let videoRef = project.video else {
            throw NSError(domain: "revunk", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video specified"])
        }

        let sourceURL = URL(fileURLWithPath: videoRef)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(
                domain: "revunk",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Video source not found: \(videoRef)"]
            )
        }

        guard let bpm = project.bpm, let downbeat = project.downbeat else {
            throw NSError(domain: "revunk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing bpm or downbeat"])
        }

        let baseBPM = bpm
        let secondsPerBeat = 60.0 / baseBPM
        let beatDuration = CMTime(seconds: secondsPerBeat, preferredTimescale: 600)
        let offset = project.offset ?? .zero
        let anchors = project.anchors.sorted { $0.index < $1.index }
        let tempoChanges = project.tempoChanges.sorted { $0.startBeat < $1.startBeat }

        // Compute cumulative time to a beat using BPM segments
        func timeFromDownbeat(toBeat beat: Int) -> CMTime {
            var time = CMTime.zero
            var currentBeat = 1
            var currentBPM = baseBPM
            var changes = tempoChanges

            while currentBeat < beat {
                let nextChangeBeat = changes.first?.startBeat ?? Int.max
                let segmentEnd = min(beat, nextChangeBeat)
                let beatsInSegment = max(0, segmentEnd - currentBeat)
                if beatsInSegment > 0 {
                    let secondsPerBeat = 60.0 / currentBPM
                    let segTime = CMTime(seconds: Double(beatsInSegment) * secondsPerBeat, preferredTimescale: 600)
                    time = CMTimeAdd(time, segTime)
                    currentBeat += beatsInSegment
                }
                if let change = changes.first, change.startBeat == currentBeat {
                    currentBPM = change.bpm
                    changes.removeFirst()
                }
            }
            return time
        }

        func timeForBeat(_ beat: Int) -> CMTime {
            let base: CMTime
            if anchors.isEmpty {
                base = CMTimeAdd(downbeat, timeFromDownbeat(toBeat: beat))
            } else if let first = anchors.first, beat <= first.index {
                let deltaTime = timeFromDownbeat(toBeat: beat) - timeFromDownbeat(toBeat: first.index)
                base = CMTimeAdd(first.time, deltaTime)
            } else {
                var interpolated: CMTime? = nil
                for (a, b) in zip(anchors, anchors.dropFirst()) {
                    if beat >= a.index && beat <= b.index {
                        let spanBeats = b.index - a.index
                        if spanBeats <= 0 { interpolated = a.time; break }
                        let t = Double(beat - a.index) / Double(spanBeats)
                        let seconds = CMTimeGetSeconds(b.time) - CMTimeGetSeconds(a.time)
                        interpolated = CMTime(seconds: CMTimeGetSeconds(a.time) + seconds * t, preferredTimescale: 600)
                        break
                    }
                }
                if let interp = interpolated {
                    base = interp
                } else if let last = anchors.last {
                    let delta = CMTimeSubtract(timeFromDownbeat(toBeat: beat), timeFromDownbeat(toBeat: last.index))
                    base = CMTimeAdd(last.time, delta)
                } else {
                    base = CMTimeAdd(downbeat, timeFromDownbeat(toBeat: beat))
                }
            }
            return CMTimeAdd(base, offset)
        }

        let asset = AVAsset(url: sourceURL)
        let composition = AVMutableComposition()

        let videoTrack = asset.tracks(withMediaType: .video).first
        let audioTrack = asset.tracks(withMediaType: .audio).first

        let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let crossfadeDurationSeconds = project.defaultCrossfade?.duration ?? 0
        let crossfadeDuration = CMTime(seconds: crossfadeDurationSeconds, preferredTimescale: 600)

        var audioMixParameters: [AVMutableAudioMixInputParameters] = []

        var cursor = CMTime.zero
        var previousAudioRange: CMTimeRange? = nil

        for edit in project.exportBeats {
            let start = timeForBeat(edit.beat)
            let range = CMTimeRange(start: start, duration: beatDuration)

            if let vt = videoTrack {
                try compVideo?.insertTimeRange(range, of: vt, at: cursor)
            }

            if let at = audioTrack, let ca = compAudio {
                try ca.insertTimeRange(range, of: at, at: cursor)

                let params = AVMutableAudioMixInputParameters(track: ca)

                if let prev = previousAudioRange, crossfadeDurationSeconds > 0 {
                    let fadeOutRange = CMTimeRange(
                        start: CMTimeSubtract(prev.start + prev.duration, crossfadeDuration),
                        duration: crossfadeDuration
                    )
                    params.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: fadeOutRange)

                    let fadeInRange = CMTimeRange(start: cursor, duration: crossfadeDuration)
                    params.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: fadeInRange)
                }

                audioMixParameters.append(params)
                previousAudioRange = CMTimeRange(start: cursor, duration: beatDuration)
            }

            cursor = CMTimeAdd(cursor, beatDuration)
        }

        var baseURL = inputURL
        if baseURL.pathExtension == "txt" {
            baseURL = baseURL.deletingPathExtension()
        }
        if baseURL.pathExtension == "revunk" || baseURL.pathExtension == "vunkle" {
            baseURL = baseURL.deletingPathExtension()
        }
        let outputURL = baseURL.appendingPathExtension("revunk.out.mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Optional debug overlay: burn beat numbers
        let videoSize = videoTrack?.naturalSize ?? CGSize(width: 1280, height: 720)
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        var overlayLayers: [CALayer] = []
        var currentTime = CMTime.zero
        for edit in project.exportBeats {
            let textLayer = CATextLayer()
            textLayer.string = "Beat \(edit.beat)"
            textLayer.fontSize = 48
            textLayer.foregroundColor = CGColor(gray: 1, alpha: 0.8)
            textLayer.backgroundColor = CGColor(gray: 0, alpha: 0.4)
            textLayer.alignmentMode = .center
            textLayer.frame = CGRect(x: 20, y: 20, width: 300, height: 80)
            textLayer.opacity = 0

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.beginTime = CMTimeGetSeconds(currentTime)
            fadeIn.duration = 0.01
            fadeIn.isRemovedOnCompletion = false
            fadeIn.fillMode = .forwards

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.beginTime = CMTimeGetSeconds(currentTime + beatDuration)
            fadeOut.duration = 0.01
            fadeOut.isRemovedOnCompletion = false
            fadeOut.fillMode = .forwards

            textLayer.add(fadeIn, forKey: nil)
            textLayer.add(fadeOut, forKey: nil)

            parentLayer.addSublayer(textLayer)
            overlayLayers.append(textLayer)
            currentTime = currentTime + beatDuration
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: composition.tracks(withMediaType: .video)[0])
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "revunk", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4

        let semaphore = DispatchSemaphore(value: 0)
        exporter.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()

        if exporter.status != .completed {
            throw exporter.error ?? NSError(domain: "revunk", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }

        // Write metadata sidecar for reopen/remix
        let fingerprint = try SourceFingerprint(originalName: sourceURL.lastPathComponent, fileURL: sourceURL)
        let metadata = MetadataVunkle(projectText: text, sources: [fingerprint])
        let metaURL = outputURL
            .deletingPathExtension()
            .appendingPathExtension("metadata.vunkle.txt")
        let metaText = metadata.asText()
        try metaText.write(to: metaURL, atomically: true, encoding: .utf8)
    }
}
