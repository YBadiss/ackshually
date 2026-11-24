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
                         providers: (any AnswerProviderFactory)? = nil,
                         suggestions: (any RulebookSuggestions)? = nil) -> AppDependencies {
        AppDependencies(credentials: credentials, settings: settings, library: library,
                        providers: providers ?? LiveAnswerProviders(credentials: credentials, settings: settings),
                        suggestions: suggestions ?? LiveRulebookSuggestions(credentials: credentials))
    }
}

/// Suggestions for previews and tests: a fixed reply (or failure) after an optional delay; `nil` reply means
/// unavailable (no server route).
struct ScriptedSuggestions: RulebookSuggestions {
    var reply: Result<[RulebookSorter.Suggestion], RulebookSorter.SortError>?
    var delay: Duration = .zero

    var isAvailable: Bool { reply != nil }

    func suggest(_ files: [RulebookSorter.File], games: [RulebookSorter.Game],
                 preferredGameID: String?) async throws -> [RulebookSorter.Suggestion] {
        if delay > .zero { try await Task.sleep(for: delay) }
        guard let reply else { throw CancellationError() }
        return try reply.get().filter { s in files.contains { $0.fileName == s.fileName } }
    }
}
