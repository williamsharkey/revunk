import Foundation
import AVFoundation
import CryptoKit

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
        let fh = try FileHandle(forReadingFrom: url)
        defer { try? fh.close() }
        let data = try fh.read(upToCount: bytes) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}
