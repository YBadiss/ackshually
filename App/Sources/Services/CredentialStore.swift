import Foundation

/// Where answers' credentials come from, in order:
/// 1. the app token bundled with the build (`ServerConfig.bundledToken`): the default, nothing to enter;
/// 2. a developer token override saved in Settings → Developer (Keychain);
/// 3. a developer's own Anthropic API key (Keychain, then `ANTHROPIC_API_KEY` from the launch environment).
///
/// Launch arguments: `-noKey YES` ignores all three (the no-credential paths stay testable on any build).
/// Debug builds: `-isolatedCredentials YES` (UI tests) keeps Keychain items under separate account names,
/// emptied at launch, and ignores the real bundled token and the environment.
enum CredentialStore {
    /// What Settings can save in the Keychain.
    enum Item: String, CaseIterable {
        case tokenOverride = "app-token-override"
        case apiKey = "anthropic-api-key"
    }

    /// The credential in use, for Settings ("Answers by …").
    enum Active: Equatable {
        case bundledToken, tokenOverride, apiKey(fromEnvironment: Bool), none
    }

    static func saved(_ item: Item) -> String? { Keychain.get(account(item)) }

    static func save(_ value: String?, _ item: Item) {
        Keychain.set(value?.trimmingCharacters(in: .whitespacesAndNewlines), for: account(item))
    }

    static var active: Active {
        if ignoresAll { return .none }
        if ServerConfig.bundledToken != nil { return .bundledToken }
        if saved(.tokenOverride) != nil { return .tokenOverride }
        if saved(.apiKey) != nil { return .apiKey(fromEnvironment: false) }
        if environmentKey != nil { return .apiKey(fromEnvironment: true) }
        return .none
    }

    /// Token → server, else API key → Anthropic directly, else nil (Settings opens on a real rulebook).
    static var route: AnswerRoute? {
        if ignoresAll { return nil }
        return AnswerRoute.resolve(bundledToken: ServerConfig.bundledToken, tokenOverride: saved(.tokenOverride),
                                   apiKey: saved(.apiKey) ?? environmentKey, serverURL: ServerConfig.baseURL)
    }

    private static var environmentKey: String? {
        if isolated { return nil }
        let k = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (k?.isEmpty ?? true) ? nil : k
    }

    private static var ignoresAll: Bool { UserDefaults.standard.bool(forKey: "noKey") }

    private static var isolated: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "isolatedCredentials")
        #else
        false
        #endif
    }

    private static func account(_ item: Item) -> String { isolated ? "uitest.\(item.rawValue)" : item.rawValue }

    /// UI tests: start every launch with nothing saved (only the isolated accounts are touched).
    static func resetIsolatedIfRequested() {
        guard isolated else { return }
        for item in Item.allCases { Keychain.set(nil, for: account(item)) }
    }
}
