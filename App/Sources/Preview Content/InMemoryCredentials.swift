import Foundation
import Synchronization
import AckshuallyCore

/// Credentials kept in memory (previews, unit tests): a bundled token if given, plus what Settings saves.
final class InMemoryCredentials: CredentialAccess {
    private let saved = Mutex<[CredentialItem: String]>([:])
    let bundledToken: String?
    let serverURL: URL

    init(bundledToken: String? = nil, serverURL: URL = URL(string: "https://ackshually.badyass.xyz")!) {
        self.bundledToken = bundledToken
        self.serverURL = serverURL
    }

    var route: AnswerRoute? {
        let s = saved.withLock { $0 }
        return AnswerRoute.resolve(bundledToken: bundledToken, tokenOverride: s[.tokenOverride], apiKey: s[.apiKey], serverURL: serverURL)
    }

    var status: RouteStatus {
        let s = saved.withLock { $0 }
        let active: ActiveCredential = bundledToken != nil ? .bundledToken
            : s[.tokenOverride] != nil ? .tokenOverride : s[.apiKey] != nil ? .apiKey(fromEnvironment: false) : .none
        return RouteStatus(active: active, serverHost: serverURL.host() ?? "", tokenOverrideSaved: s[.tokenOverride] != nil,
                           apiKeySaved: s[.apiKey] != nil)
    }

    func save(_ value: String?, for item: CredentialItem) {
        let v = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.withLock { $0[item] = (v?.isEmpty ?? true) ? nil : v }
    }
}
