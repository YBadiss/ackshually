import Foundation
import Security

/// Minimal generic-password Keychain wrapper for the dev-only API key.
enum Keychain {
    private static let service = "app.ackshually.viewer"

    static func get(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ value: String?, for account: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Where the API key comes from: Keychain (settings screen) first, then the process environment
/// (simulator: `SIMCTL_CHILD_ANTHROPIC_API_KEY=… xcrun simctl launch …`, or the Xcode scheme).
enum APIKeyStore {
    static let account = "anthropic-api-key"

    static var keychainKey: String? { Keychain.get(account) }
    static var environmentKey: String? {
        let k = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (k?.isEmpty ?? true) ? nil : k
    }
    static var current: String? { keychainKey ?? environmentKey }
}
