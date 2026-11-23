import Foundation

/// What Settings can save in the Keychain.
enum CredentialItem: String, CaseIterable, Sendable {
    case tokenOverride = "app-token-override"
    case apiKey = "anthropic-api-key"
}

/// The credential in use, for Settings ("Answers by …").
enum ActiveCredential: Equatable, Sendable {
    case bundledToken, tokenOverride, apiKey(fromEnvironment: Bool), none
}
