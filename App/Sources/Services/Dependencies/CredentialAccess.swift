import Foundation

/// Where answers' credentials come from and where Settings saves them. Live: `LiveCredentials` (Keychain,
/// bundled token, environment); previews and tests: `InMemoryCredentials`.
protocol CredentialAccess: Sendable {
    /// Token → server, else API key → Anthropic directly, else nil (Settings opens on a real rulebook).
    var route: AnswerRoute? { get }
    /// What Settings shows.
    var status: RouteStatus { get }
    /// nil (or empty) removes the item.
    func save(_ value: String?, for item: CredentialItem)
}

/// The app's credentials: `CredentialStore` (Keychain, bundled token, `ANTHROPIC_API_KEY`) and `ServerConfig`.
struct LiveCredentials: CredentialAccess {
    var route: AnswerRoute? { CredentialStore.route }

    var status: RouteStatus {
        RouteStatus(active: CredentialStore.active, serverHost: ServerConfig.host,
                    tokenOverrideSaved: CredentialStore.saved(.tokenOverride) != nil,
                    apiKeySaved: CredentialStore.saved(.apiKey) != nil)
    }

    func save(_ value: String?, for item: CredentialItem) { CredentialStore.save(value, item) }
}
