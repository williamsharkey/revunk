import Foundation
#if canImport(Network)
import Network
#endif

public final class VunkleHTTPServer {
    private let port: UInt16
    private let root: URL
    private var listener: NWListener?

    public init(port: UInt16 = 8080, root: URL) {
        self.port = port
        self.root = root
    }

    public func start() {
        #if canImport(Network)
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { conn in
            conn.start(queue: .main)
            self.handle(conn)
        }
        listener?.start(queue: .main)
        print("HTTP server running at http://localhost:\(port)")
        #endif
    }

    private func handle(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            guard let data, let req = String(data: data, encoding: .utf8) else { return }
            let path = req.split(separator: " ").dropFirst().first ?? "/"
            let fileURL = self.root.appendingPathComponent(path == "/" ? "index.html" : String(path.dropFirst()))
            let body = (try? Data(contentsOf: fileURL)) ?? Data("Not found".utf8)
            let header = "HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n"
            conn.send(content: header.data(using: .utf8)! + body, completion: .contentProcessed { _ in })
        }
    }
}
