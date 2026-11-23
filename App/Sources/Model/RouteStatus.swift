import Foundation

/// What Settings shows about the answer route: plain values, built by `CredentialAccess.status` (or fixtures).
struct RouteStatus: Equatable {
    var active: ActiveCredential
    var serverHost: String
    var tokenOverrideSaved = false
    var apiKeySaved = false

    var title: String {
        switch active {
        case .bundledToken, .tokenOverride: "Answers by ackshually server"
        case .apiKey: "Answers by the Anthropic API"
        case .none: "No answer service set up"
        }
    }

    var detail: String {
        switch active {
        case .bundledToken: "Built into this app · \(serverHost)"
        case .tokenOverride: "Developer token · \(serverHost)"
        case .apiKey(let env): env ? "Your own API key, from ANTHROPIC_API_KEY" : "Your own API key"
        case .none: "The sample rulebook still gets demo answers. Your own rulebooks need an access token or an API key (Developer, below)."
        }
    }

    var footer: String? {
        switch active {
        case .bundledToken, .tokenOverride:
            "Questions and the rulebook pages they need go to Claude through the ackshually server, which keeps the Anthropic key and a daily limit."
        case .apiKey: "Questions go straight to Anthropic, billed to your key."
        case .none: nil
        }
    }

    var systemImage: String {
        switch active {
        case .bundledToken, .tokenOverride: "checkmark.seal.fill"
        case .apiKey: "key.fill"
        case .none: "exclamationmark.triangle.fill"
        }
    }

    var isSetUp: Bool { active != .none }
}
