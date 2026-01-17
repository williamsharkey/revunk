import Foundation
#if canImport(Network)
import Network
#endif

public final class VunkleWebSocketServer {
    private let port: UInt16
    private var listener: NWListener?
    private var stateText: String

    public init(port: UInt16 = 8080, initialText: String) {
        self.port = port
        self.stateText = initialText
    }

    public func start() {
        #if canImport(Network)
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { conn in
            conn.start(queue: .main)
            self.sendState(on: conn)
            self.receive(on: conn)
        }
        listener?.start(queue: .main)
        print("WebSocket server listening on ws://localhost:\(port)")
        #else
        print("Network framework unavailable; WebSocket server disabled")
        #endif
    }

    private func sendState(on conn: NWConnection) {
        let msg = WebMessage(type: .state, text: stateText)
        let data = try! JSONEncoder().encode(msg)
        conn.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in
            if let data,
               let msg = try? JSONDecoder().decode(WebMessage.self, from: data) {
                self.handle(msg: msg, conn: conn)
            }
            self.receive(on: conn)
        }
    }

    private func handle(msg: WebMessage, conn: NWConnection) {
        switch msg.type {
        case .update:
            if let t = msg.text { stateText = t }
            sendState(on: conn)
        case .format:
            let formatted = VunkleFormatCLI.format(text: stateText)
            stateText = formatted
            sendState(on: conn)
        default:
            break
        }
    }
}
