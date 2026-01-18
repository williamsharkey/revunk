import Foundation

public final class SourceDiscovery {
    public static func find(matches fingerprints: [SourceFingerprint], searchPaths: [URL]) -> [SourceFingerprint: URL] {
        var results: [SourceFingerprint: URL] = [:]
        for dir in searchPaths {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for f in files {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: f.path),
                      let size = attrs[.size] as? UInt64 else { continue }
                for fp in fingerprints where results[fp] == nil && fp.fileSize == size {
                    results[fp] = f
                }
            }
        }
        return results
    }
}
