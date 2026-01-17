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
struct VunkleDetectGridCLI {
    static func main() async {
        guard CommandLine.arguments.count >= 2 else {
            fatalError("usage: vunkle-detect-grid video.mp4 [--debug]")
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let debug = CommandLine.arguments.contains("--debug")

        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let duration = asset.duration.seconds
        let step = 0.05

        var lastIndex: Int? = nil
        var beatTimes: [CMTime] = []

        for t in stride(from: 0.0, to: duration, by: step) {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }

            let (values, crop) = sampleGrid(image: image, grid: defaultGrid)
            guard let values else { continue }

            let sorted = values.sorted()
            let median = sorted[values.count / 2]
            let maxVal = sorted.last!
            guard maxVal / max(median, 0.001) > 1.8 else { continue }

            let index = values.firstIndex(of: maxVal)!
            if index != lastIndex {
                beatTimes.append(time)
                lastIndex = index
                if debug, let crop { savePNG(crop, name: "grid-debug-\(beatTimes.count).png") }
            }
        }

        guard beatTimes.count >= 8 else {
            fatalError("not enough beats detected")
        }

        let intervals = zip(beatTimes.dropFirst(), beatTimes).map { $0.0.seconds - $0.1.seconds }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60.0 / avgInterval

        print(String(format: "Estimated BPM: %.3f", bpm))
        print("Suggested anchors:")
        for (i, t) in beatTimes.prefix(4).enumerated() {
            print("  beat \(1 + i * 16) @ \(String(format: "%.3f", t.seconds))")
        }
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
