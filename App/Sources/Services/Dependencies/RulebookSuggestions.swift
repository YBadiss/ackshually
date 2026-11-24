import Foundation
import AckshuallyCore

/// Who suggests which game each picked PDF belongs to (S14). Live: `RulebookSorter` (Claude Haiku) through the
/// ackshually server only, with the bundled token or the developer token override; a developer's own API key
/// or no credential means no suggestions (the user sorts). Unit tests inject `ScriptedSuggestions`.
protocol RulebookSuggestions: Sendable {
    /// False without a server route: the review sheet then shows the files unsorted right away.
    var isAvailable: Bool { get }
    func suggest(_ files: [RulebookSorter.File], games: [RulebookSorter.Game],
                 preferredGameID: String?) async throws -> [RulebookSorter.Suggestion]
}

struct LiveRulebookSuggestions: RulebookSuggestions {
    var credentials: any CredentialAccess

    private var server: (token: String, url: URL)? {
        guard case .server(let token, let url) = credentials.route else { return nil }
        return (token, url)
    }

    var isAvailable: Bool { server != nil }

    func suggest(_ files: [RulebookSorter.File], games: [RulebookSorter.Game],
                 preferredGameID: String?) async throws -> [RulebookSorter.Suggestion] {
        guard let server else { throw CancellationError() }
        return try await RulebookSorter(credential: .appToken(server.token), baseURL: server.url)
            .sort(files, games: games, preferredGameID: preferredGameID)
    }
}
