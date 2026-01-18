import Foundation
import AVFoundation
import CoreImage
import AppKit

struct GridCalibration {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

let defaultGrid = GridCalibration(x: 0.38, y: 0.04, w: 0.24, h: 0.24)

@main
struct RevunkDetectGridCLI {
    static func main() async {
        guard CommandLine.arguments.count >= 2 else {
            fatalError("usage: revunk-detect-grid video.mp4 [--debug] [--emit-revunk] [--grid x y w h]")
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let debug = CommandLine.arguments.contains("--debug")
        let emit = CommandLine.arguments.contains("--emit-revunk")

        let grid = parseGridOverride() ?? defaultGrid

        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let duration = asset.duration.seconds
        let step = 0.05

        var lastIndex: Int? = nil
        var absoluteBeat = 0
        var beatEvents: [(Int, CMTime)] = []

        for t in stride(from: 0.0, to: duration, by: step) {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }

            let (values, crop) = sampleGrid(image: image, grid: grid)
            guard let values else { continue }

            let sorted = values.sorted()
            let median = sorted[values.count / 2]
            let maxVal = sorted.last!
            guard maxVal / max(median, 0.001) > 1.8 else { continue }

            let index = values.firstIndex(of: maxVal)!

            if let li = lastIndex {
                if li == 15 && index == 0 { absoluteBeat += 1 }
                else if index != li { absoluteBeat += 1 }
            } else {
                absoluteBeat = 1
            }

            if index != lastIndex {
                beatEvents.append((absoluteBeat, time))
                lastIndex = index
                if debug, let crop { savePNG(crop, name: "grid-debug-\(beatEvents.count).png") }
            }
        }

        guard beatEvents.count >= 8 else {
            fatalError("not enough beats detected")
        }

        let times = beatEvents.map { $0.1.seconds }
        let intervals = zip(times.dropFirst(), times).map { $0.0 - $0.1 }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60.0 / avgInterval

        print(String(format: "Estimated BPM: %.3f", bpm))

        let anchors = stride(from: 0, to: beatEvents.count, by: 16).prefix(4).map { beatEvents[$0] }

        print("Suggested anchors:")
        for (b, t) in anchors {
            print("  beat \(b) @ \(String(format: "%.3f", t.seconds))")
        }

        if emit {
            emitRevunk(videoURL: videoURL, bpm: bpm, anchors: anchors, grid: grid)
        }
    }

    static func parseGridOverride() -> GridCalibration? {
        guard let i = CommandLine.arguments.firstIndex(of: "--grid"),
              CommandLine.arguments.count >= i + 5,
              let x = Double(CommandLine.arguments[i+1]),
              let y = Double(CommandLine.arguments[i+2]),
              let w = Double(CommandLine.arguments[i+3]),
              let h = Double(CommandLine.arguments[i+4])
        else { return nil }
        return GridCalibration(x: x, y: y, w: w, h: h)
    }

    static func emitRevunk(videoURL: URL, bpm: Double, anchors: [(Int, CMTime)], grid: GridCalibration) {
        let outURL = videoURL.deletingPathExtension().appendingPathExtension("auto.revunk.txt")
        var lines: [String] = []
        lines.append("video: \(videoURL.lastPathComponent)")
        lines.append("")
        lines.append(String(format: "bpm: %.3f", bpm))
        lines.append("")
        lines.append("# visual grid calibration")
        lines.append("grid:")
        lines.append(String(format: "  x %.4f", grid.x))
        lines.append(String(format: "  y %.4f", grid.y))
        lines.append(String(format: "  w %.4f", grid.w))
        lines.append(String(format: "  h %.4f", grid.h))
        lines.append("")
        lines.append("# auto-detected from visual grid")
        lines.append("anchor:")
        for (b, t) in anchors {
            lines.append(String(format: "  %d %.3f", b, t.seconds))
        }
        lines.append("")
        lines.append("export:")
        lines.append("  1 2 3 4")

        try? lines.joined(separator: "\n").write(to: outURL, atomically: true, encoding: .utf8)
        print("wrote", outURL.path)
    }

    static func sampleGrid(image: CGImage, grid: GridCalibration) -> ([Double]?, CGImage?) {
        let w = image.width
        let h = image.height
        let gx = Int(Double(w) * grid.x)
        let gy = Int(Double(h) * grid.y)
        let gw = Int(Double(w) * grid.w)
        let gh = Int(Double(h) * grid.h)
        guard let cropped = image.cropping(to: CGRect(x: gx, y: gy, width: gw, height: gh)) else { return (nil, nil) }

        let ctx = CGContext(data: nil, width: cropped.width, height: cropped.height, bitsPerComponent: 8, bytesPerRow: cropped.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        let data = ctx.data!.assumingMemoryBound(to: UInt8.self)

        var values: [Double] = []
        for i in 0..<16 {
            let row = i / 4
            let col = i % 4
            let cx = cropped.width * col / 4
            let cy = cropped.height * row / 4
            let cw = cropped.width / 4
            let ch = cropped.height / 4
            var sum = 0.0
            var count = 0
            for y in cy..<(cy + ch) {
                for x in cx..<(cx + cw) {
                    let idx = (y * cropped.width + x) * 4
                    let r = Double(data[idx])
                    let g = Double(data[idx + 1])
                    let b = Double(data[idx + 2])
                    sum += 0.2126*r + 0.7152*g + 0.0722*b
                    count += 1
                }
            }
            values.append(sum / Double(count))
        }
        return (values, cropped)
    }

    static func savePNG(_ image: CGImage, name: String) {
        let rep = NSBitmapImageRep(cgImage: image)
        let data = rep.representation(using: .png, properties: [:])!
        try? data.write(to: URL(fileURLWithPath: name))
    }
}
