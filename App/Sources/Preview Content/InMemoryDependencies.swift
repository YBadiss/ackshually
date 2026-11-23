import UIKit
import Synchronization
import AckshuallyCore

// In-memory dependencies for previews and unit tests: nothing touches the Keychain, UserDefaults or the
// library folder.

extension AppDependencies {
    /// Previews' default (also the environment's): no credential, demo answers for the sample, an empty library.
    static let preview = AppDependencies.inMemory()

    static func inMemory(credentials: InMemoryCredentials = InMemoryCredentials(),
                         settings: InMemorySettings = InMemorySettings(),
                         library: InMemoryLibraryStorage = InMemoryLibraryStorage(),
                         providers: (any AnswerProviderFactory)? = nil) -> AppDependencies {
        AppDependencies(credentials: credentials, settings: settings, library: library,
                        providers: providers ?? LiveAnswerProviders(credentials: credentials, settings: settings))
    }
}
