import Foundation
import AVFoundation


public struct SourceFingerprint: Equatable, Codable {
    public let originalName: String
    public let fileSize: UInt64
    public let durationSeconds: Double
    public let sha256Prefix: String

    public init(originalName: String, fileURL: URL) throws {
        self.originalName = originalName
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        self.fileSize = attrs[.size] as? UInt64 ?? 0
        let asset = AVURLAsset(url: fileURL)
        self.durationSeconds = asset.duration.seconds
        self.sha256Prefix = try Self.hashPrefix(url: fileURL)
    }

    private static func hashPrefix(url: URL, bytes: Int = 1024 * 1024) throws -> String {
        // Read a small prefix for fast identification (cross-platform)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let slice = data.prefix(bytes)
        // Cross-platform fast checksum (not cryptographic)
        var checksum: UInt64 = 0
        for b in slice { checksum = (checksum &* 1315423911) ^ UInt64(b) }
        return String(format: "%016llx", checksum)
    }
}
