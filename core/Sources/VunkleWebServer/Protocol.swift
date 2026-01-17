import Foundation

public enum WebMessageType: String, Codable {
    case load
    case update
    case format
    case export
    case state
    case log
}

public struct WebMessage: Codable {
    public let type: WebMessageType
    public let text: String?
    public let message: String?

    public init(type: WebMessageType, text: String? = nil, message: String? = nil) {
        self.type = type
        self.text = text
        self.message = message
    }
}
