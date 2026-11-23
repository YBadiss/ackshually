import Foundation
import AckshuallyCore

/// Where a question goes. The default is the ackshually server with an access token (it holds the Anthropic
/// key); a developer's own API key calls Anthropic directly. The credential never appears in `description`,
/// so a route can be logged.
enum AnswerRoute: Equatable, Sendable, CustomStringConvertible {
    case server(token: String, url: URL)
    case direct(apiKey: String)

    enum Kind: String, Codable, Sendable {
        case server, direct, demo

        var title: String {
            switch self {
            case .server: "ackshually server"
            case .direct: "Anthropic API (own key)"
            case .demo: "Demo answers"
            }
        }

        /// Answer Details' "Answered by" row.
        func label(serverHost: String) -> String { self == .server ? "\(title) · \(serverHost)" : title }
    }

    /// Precedence: bundled token → server; otherwise a developer token override → server; otherwise an API
    /// key → Anthropic directly; otherwise none.
    static func resolve(bundledToken: String?, tokenOverride: String?, apiKey: String?, serverURL: URL) -> AnswerRoute? {
        if let t = bundledToken.nonEmpty ?? tokenOverride.nonEmpty { return .server(token: t, url: serverURL) }
        if let k = apiKey.nonEmpty { return .direct(apiKey: k) }
        return nil
    }

    var kind: Kind {
        switch self {
        case .server: .server
        case .direct: .direct
        }
    }

    func claudeConfig(model: String) -> ClaudeConfig {
        switch self {
        case .server(let token, let url):
            ClaudeConfig(credential: .appToken(token), model: model, effort: "low", mode: .json, baseURL: url)
        case .direct(let key):
            ClaudeConfig(apiKey: key, model: model, effort: "low", mode: .json)
        }
    }

    var description: String {
        switch self {
        case .server(_, let url): "server \(url.absoluteString)"
        case .direct: "direct api.anthropic.com"
        }
    }
}

private extension Optional<String> {
    var nonEmpty: String? { self.flatMap { $0.isEmpty ? nil : $0 } }
}
