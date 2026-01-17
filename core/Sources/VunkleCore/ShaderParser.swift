import Foundation

public final class ShaderParser {
    public static func parse(from text: String) -> [VunkleShader] {
        var shaders: [VunkleShader] = []
        var current: [String: String] = [:]

        for line in text.split(separator: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s == "shader:" {
                if !current.isEmpty {
                    shaders.append(build(from: current))
                    current.removeAll()
                }
            } else if s.contains(" ") {
                let parts = s.split(separator: " ", maxSplits: 1).map(String.init)
                current[parts[0]] = parts[1]
            }
        }

        if !current.isEmpty {
            shaders.append(build(from: current))
        }

        return shaders
    }

    private static func build(from dict: [String: String]) -> VunkleShader {
        let id = dict["id"] ?? UUID().uuidString
        let file = URL(fileURLWithPath: dict["file"] ?? "")
        let applyRange: BeatRange
        if let r = dict["apply"], r.contains("..") {
            let nums = r.split(separator: ".").compactMap { Int($0) }
            applyRange = nums.count == 2 ? .range(nums[0], nums[1]) : .all
        } else {
            applyRange = .all
        }

        var params: [String: Double] = [:]
        for (k, v) in dict where k != "id" && k != "file" && k != "apply" {
            params[k] = Double(v) ?? 0
        }

        return VunkleShader(id: id, file: file, applyRange: applyRange, params: params)
    }
}
