import SwiftUI
import AckshuallyCore

/// The games, most recently opened first. Rows push the viewer (`GameRoute.game`; a game with add-ons asks
/// what you play with first); swipe deletes.
/// Covers load per visible row through `loadCover`.
struct GameList: View {
    var games: [LibraryEntry]
    var covers: [String: UIImage]
    var loadCover: (LibraryEntry, _ pixelWidth: Int, _ scale: CGFloat) async -> Void
    var onDelete: ([LibraryEntry]) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    /// Rendered a bit wider than shown so small text-size changes reuse the same cover.
    private var pixelWidth: Int {
        let px = theme.size.coverWidth * displayScale
        return Int((px / 64).rounded(.up) * 64)
    }

    var body: some View {
        List {
            ForEach(games) { game in
                NavigationLink(value: GameRoute.game(id: game.id)) {
                    GameRow(title: game.title, books: game.bookCountText, lastOpened: game.lastOpened,
                            cover: game.coverBook.flatMap { covers[$0.fileName] })
                }
                .accessibilityIdentifier("game-\(game.id)")
                .task(id: pixelWidth) { await loadCover(game, pixelWidth, displayScale) }
            }
            .onDelete { offsets in onDelete(offsets.map { games[$0] }) }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("gameList")
    }
}

#Preview {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: LibraryFixtures.covers, loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
    }
    .themed()
}
#Preview("Dark") {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: [:], loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
    }
    .themed()
    .preferredColorScheme(.dark)
}
