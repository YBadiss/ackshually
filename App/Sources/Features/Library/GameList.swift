import SwiftUI
import AckshuallyCore

/// The games, most recently opened first. Rows push the viewer (`GameRoute.game`; a game with add-ons asks
/// what you play with first); swipe deletes; in Edit mode rows are selected (`selection`) for Delete.
/// Covers load per visible row through `loadCover`.
struct GameList: View {
    var games: [LibraryEntry]
    var covers: [String: UIImage]
    @Binding var selection: Set<String>
    var loadCover: (LibraryEntry, _ pixelWidth: Int, _ scale: CGFloat) async -> Void
    /// Swipe → Delete (the model asks first when the game has several books).
    var onDelete: ([LibraryEntry]) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    /// Rendered a bit wider than shown so small text-size changes reuse the same cover.
    private var pixelWidth: Int {
        let px = theme.size.coverWidth * displayScale
        return Int((px / 64).rounded(.up) * 64)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(games) { game in
                NavigationLink(value: GameRoute.game(id: game.id)) {
                    GameRow(title: game.title, books: game.bookCountText, lastOpened: game.lastOpened,
                            cover: game.coverBook.flatMap { covers[$0.fileName] })
                }
                .tag(game.id)
                .accessibilityIdentifier("game-\(game.id)")
                .swipeActions(edge: .trailing, allowsFullSwipe: game.books.count == 1) {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete([game]) }
                }
                .task(id: pixelWidth) { await loadCover(game, pixelWidth, displayScale) }
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("gameList")
    }
}

#Preview {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: LibraryFixtures.covers, selection: .constant([]),
                 loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
    }
    .themed()
}
#Preview("Editing, two selected") {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: LibraryFixtures.covers,
                 selection: .constant(["tile-garden.pdf", "woodland-court.pdf"]), loadCover: { _, _, _ in }, onDelete: { _ in })
            .environment(\.editMode, .constant(.active))
            .navigationTitle("My Games")
    }
    .themed()
}
#Preview("Dark") {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: [:], selection: .constant([]), loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
    }
    .themed()
    .preferredColorScheme(.dark)
}
