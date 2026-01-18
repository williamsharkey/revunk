import Foundation
#if canImport(Network)
import Network
#endif

public final class RevunkWebServer {
    private let port: UInt16
    private var listener: NWListener?

    public init(port: UInt16 = 8080) {
        self.port = port
    }

    public func start(fileURL: URL, initialText: String) {
        #if canImport(Network)
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { conn in
            conn.start(queue: .main)
            self.handle(connection: conn, text: initialText)
        }

        listener?.start(queue: .main)
        print("Revunk web server running at http://localhost:\(port)")
        #else
        print("Network framework unavailable; web server not started")
        #endif
    }

    private func handle(connection: NWConnection, text: String) {
        let welcome = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nRevunk Web Server".data(using: .utf8)!
        connection.send(content: welcome, completion: .contentProcessed { _ in })
    }
}
