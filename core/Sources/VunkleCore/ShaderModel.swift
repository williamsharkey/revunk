import Foundation

public struct VunkleShader: Equatable {
    public let id: String
    public let file: URL
    public let applyRange: BeatRange
    public let params: [String: Double]

    public init(id: String, file: URL, applyRange: BeatRange, params: [String: Double] = [:]) {
        self.id = id
        self.file = file
        self.applyRange = applyRange
        self.params = params
    }
}

public enum BeatRange: Equatable {
    case all
    case range(Int, Int)
}
