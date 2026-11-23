import Foundation
import Network

/// A local stand-in for the ackshually server, so UI tests never reach the real one. It listens on
/// 127.0.0.1 (the simulator shares the Mac's network), records each request's headers and answers
/// `POST /v1/messages` according to the fake token:
///   fake-ok → a streamed answer (`answerJSON`) · fake-revoked → 401 · fake-busy → 429 with retry-after 30
///   · fake-daily → 429 without retry-after (the daily cap). Error bodies use Anthropic's shape, like the server.
final class StubServer: @unchecked Sendable {
    struct Request { var method: String; var path: String; var headers: [String: String] }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "stub-server")
    private let lock = NSLock()
    private var requests: [Request] = []
    private let answerJSON: String

    var seen: [Request] { lock.withLock { requests } }
    var url: String { "http://127.0.0.1:\(listener.port?.rawValue ?? 0)" }

    init(answerJSON: String) throws {
        self.answerJSON = answerJSON
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: params)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        listener.newConnectionHandler = { [weak self] c in self?.accept(c) }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 5)
    }

    func stop() { listener.cancel() }

    private func accept(_ c: NWConnection) {
        c.start(queue: queue)
        read(c, buffer: Data())
    }

    /// Reads the head, then the body up to content-length, then answers.
    private func read(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let head = buf.range(of: Data("\r\n\r\n".utf8)) {
                let req = Self.parse(String(decoding: buf[..<head.lowerBound], as: UTF8.self))
                let length = Int(req.headers["content-length"] ?? "0") ?? 0
                if buf.count - head.upperBound >= length {
                    self.lock.withLock { self.requests.append(req) }
                    return self.respond(c, to: req)
                }
            }
            if done || error != nil { return c.cancel() }
            self.read(c, buffer: buf)
        }
    }

    private static func parse(_ head: String) -> Request {
        let lines = head.components(separatedBy: "\r\n")
        let start = lines.first?.split(separator: " ").map(String.init) ?? []
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let i = line.firstIndex(of: ":") else { continue }
            headers[line[..<i].lowercased()] = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }
        return Request(method: start.first ?? "", path: start.dropFirst().first ?? "", headers: headers)
    }

    private func respond(_ c: NWConnection, to req: Request) {
        let token = req.headers["authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
        let response: String
        switch (req.method, req.path, token) {
        case ("POST", "/v1/messages", "fake-ok"):
            response = head(200, ["content-type": "text/event-stream"]) + sse()
        case ("POST", "/v1/messages", "fake-busy"):
            response = error(429, "rate_limit_error", "Too many requests, try again shortly", ["retry-after": "30"])
        case ("POST", "/v1/messages", "fake-daily"):
            response = error(429, "rate_limit_error", "Today's usage limit is reached, try again tomorrow")
        case ("POST", "/v1/messages", _):
            response = error(401, "authentication_error", "Missing or unknown app token")
        default:
            response = error(404, "not_found_error", "Not found")
        }
        c.send(content: Data(response.utf8), completion: .contentProcessed { _ in c.cancel() })
    }

    private func head(_ status: Int, _ headers: [String: String]) -> String {
        let reason = [200: "OK", 401: "Unauthorized", 404: "Not Found", 429: "Too Many Requests"][status] ?? "Error"
        let lines = headers.merging(["connection": "close"]) { a, _ in a }.map { "\($0): \($1)" }
        return "HTTP/1.1 \(status) \(reason)\r\n" + lines.joined(separator: "\r\n") + "\r\n\r\n"
    }

    private func error(_ status: Int, _ type: String, _ message: String, _ extra: [String: String] = [:]) -> String {
        let body = #"{"type":"error","error":{"type":"\#(type)","message":"\#(message)"}}"#
        return head(status, extra.merging(["content-type": "application/json", "content-length": "\(body.utf8.count)"]) { a, _ in a }) + body
    }

    private func sse() -> String {
        func event(_ obj: [String: Any]) -> String {
            let d = try! JSONSerialization.data(withJSONObject: obj)
            return "event: \(obj["type"]!)\ndata: \(String(decoding: d, as: UTF8.self))\n\n"
        }
        return [
            event(["type": "message_start", "message": ["model": "claude-sonnet-5-5", "usage": ["input_tokens": 10, "output_tokens": 1]]]),
            event(["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]]),
            event(["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": answerJSON]]),
            event(["type": "content_block_stop", "index": 0]),
            event(["type": "message_delta", "delta": ["stop_reason": "end_turn"], "usage": ["output_tokens": 50]]),
            event(["type": "message_stop"]),
        ].joined()
    }
}
