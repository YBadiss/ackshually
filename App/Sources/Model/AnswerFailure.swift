import Foundation
import AckshuallyCore

/// A failed answer as the user sees it: what happened, and whether Settings is where to fix it.
struct AnswerFailure: Equatable {
    var message: String
    var opensSettings = false

    /// Maps provider errors to messages. The server answers in Anthropic's error shape; its 429s are the
    /// per-minute limit (with `retry-after`) or the daily cap (without).
    init(_ error: Error, route: AnswerRoute.Kind) {
        if let e = error as? ClaudeAPIError {
            self = Self.api(e, route: route)
        } else if let u = error as? URLError {
            self = Self.network(u, route: route)
        } else {
            message = error.localizedDescription
        }
    }

    init(message: String, opensSettings: Bool = false) {
        self.message = message
        self.opensSettings = opensSettings
    }

    private static func api(_ e: ClaudeAPIError, route: AnswerRoute.Kind) -> AnswerFailure {
        let server = route == .server
        switch e.status {
        case 401, 403:
            return server
                ? .init(message: "The server didn't accept your access token. It may be mistyped or revoked: check it in Settings.", opensSettings: true)
                : .init(message: "Anthropic rejected your API key. Check it in Settings.", opensSettings: true)
        case 429:
            if server, e.retryAfter == nil {
                return .init(message: "Today's question limit is reached. Try again tomorrow.")
            }
            return .init(message: "Too many questions at once. Try again \(wait(e.retryAfter)).")
        case 529, 503:
            return .init(message: "Claude is overloaded. Try again in a moment.")
        case 502 where server:
            return .init(message: "The server couldn't reach Claude. Try again in a moment.")
        case 413:
            return .init(message: "This rulebook is too large to send.")
        default:
            if let m = e.message { return .init(message: "Something went wrong (HTTP \(e.status)): \(m)") }
            return .init(message: e.status == 0 ? e.body : "Something went wrong (HTTP \(e.status)).")
        }
    }

    private static func wait(_ seconds: TimeInterval?) -> String {
        guard let s = seconds, s > 0 else { return "in a moment" }
        if s <= 60 { return "in \(Int(s.rounded(.up))) seconds" }
        return "in \(Int((s / 60).rounded(.up))) minutes"
    }

    private static func network(_ u: URLError, route: AnswerRoute.Kind) -> AnswerFailure {
        if u.code == .notConnectedToInternet { return .init(message: "No internet connection.") }
        if route == .server, [.cannotFindHost, .cannotConnectToHost, .timedOut].contains(u.code) {
            return .init(message: "Couldn't reach the ackshually server. Try again in a moment.")
        }
        return .init(message: u.localizedDescription)
    }
}
