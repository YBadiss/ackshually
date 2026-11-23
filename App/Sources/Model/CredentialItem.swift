import Foundation

/// What Settings can save in the Keychain.
enum CredentialItem: String, CaseIterable, Sendable {
    case tokenOverride = "app-token-override"
    case apiKey = "anthropic-api-key"
}
