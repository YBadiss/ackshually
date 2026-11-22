import Foundation

/// The ackshually server (`Server/`) and the app token that ships with the build. Both come from build
/// settings (`App/Config/Base.xcconfig`, the token from the git-ignored `Secrets.xcconfig`) through
/// Info.plist (`AckshuallyServerURL`, `AckshuallyAppToken`).
///
/// Debug builds only (UI tests): `-serverURL http://127.0.0.1:…` points at a local stub and `-appToken …`
/// replaces the bundled token with a fake one; `-isolatedCredentials YES` ignores the real bundled token.
enum ServerConfig {
    static let urlKey = "AckshuallyServerURL"
    static let tokenKey = "AckshuallyAppToken"

    static var baseURL: URL {
        #if DEBUG
        if let s = UserDefaults.standard.string(forKey: "serverURL"), let u = URL(string: s), u.host() != nil { return u }
        #endif
        return builtInURL
    }

    static var host: String { baseURL.host() ?? baseURL.absoluteString }

    /// The bundled token, nil when the build has none (empty or missing `Secrets.xcconfig`).
    static var bundledToken: String? {
        #if DEBUG
        let d = UserDefaults.standard
        if let t = d.string(forKey: "appToken") { return t.isEmpty ? nil : t }
        if d.bool(forKey: "isolatedCredentials") { return nil }
        #endif
        return builtInToken
    }

    private static let builtInURL: URL = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
              let u = URL(string: s), u.scheme == "https", u.host() != nil else {
            preconditionFailure("\(urlKey) in Info.plist must be an https URL (ACKSHUALLY_SERVER_URL build setting)")
        }
        return u
    }()

    private static let builtInToken: String? = {
        let t = (Bundle.main.object(forInfoDictionaryKey: tokenKey) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset build setting can arrive literally as "$(ACKSHUALLY_APP_TOKEN)".
        guard let t, !t.isEmpty, !t.hasPrefix("$(") else { return nil }
        return t
    }()
}
