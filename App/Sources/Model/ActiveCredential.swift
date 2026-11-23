import Foundation

/// The credential in use, for Settings ("Answers by …").
enum ActiveCredential: Equatable, Sendable {
    case bundledToken, tokenOverride, apiKey(fromEnvironment: Bool), none
}
