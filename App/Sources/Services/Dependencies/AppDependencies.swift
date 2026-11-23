import SwiftUI

/// Everything the app reads from outside itself, created once in `AckshuallyApp` (`.live`) and handed to the
/// models by initialiser and to the few glue views (Settings) through the environment. Previews and unit tests
/// use in-memory versions (`AppDependencies.preview`, `InMemory…`), so no Keychain, UserDefaults or files.
struct AppDependencies: Sendable {
    var credentials: any CredentialAccess
    var settings: any AppSettings
    var library: any LibraryStorage
    var providers: any AnswerProviderFactory

    static func live() -> AppDependencies {
        let credentials = LiveCredentials()
        let settings = UserDefaultsSettings()
        return AppDependencies(credentials: credentials, settings: settings, library: FileLibraryStorage(),
                               providers: LiveAnswerProviders(credentials: credentials, settings: settings))
    }
}

extension EnvironmentValues {
    /// Defaults to the in-memory preview set (a stable instance), so a preview never touches the Keychain.
    @Entry var dependencies: AppDependencies = AppDependencies.preview
}
