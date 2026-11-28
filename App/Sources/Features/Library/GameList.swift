import SwiftUI
import AckshuallyCore

/// The games, most recently opened first. Rows push the viewer (`GameRoute.game`; a game with add-ons asks
/// what you play with first); long press → Open, Rename…, Delete; swipe → Delete (full swipe too; the model
/// asks first for a game with several books). While selecting (`editMode` active) rows are plain, with no
/// chevron, and the system's checkmark circle shows the selection (`selection`). Covers load per visible row
/// through `loadCover`.
struct GameList: View {
    var games: [LibraryEntry]
    var covers: [String: UIImage]
    @Binding var selection: Set<String>
    var loadCover: (LibraryEntry, _ pixelWidth: Int, _ scale: CGFloat) async -> Void
    /// Opens a game (the context menu's Open).
    var onOpen: (LibraryEntry) -> Void = { _ in }
    var onRename: (LibraryEntry) -> Void = { _ in }
    /// Swipe or context menu → Delete (the model asks first when the game has several books).
    var onDelete: ([LibraryEntry]) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.editMode) private var editMode

    private var isSelecting: Bool { editMode?.wrappedValue.isEditing ?? false }

    /// Rendered a bit wider than shown so small text-size changes reuse the same cover.
    private var pixelWidth: Int {
        let px = theme.size.coverWidth * displayScale
        return Int((px / 64).rounded(.up) * 64)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(games) { game in
                row(game)
                    .tag(game.id)
                    .listRowBackground(theme.colors.card)
                    .accessibilityIdentifier("game-\(game.id)")
                    .contextMenu {
                        Button("Open", systemImage: "book") { onOpen(game) }
                        Button("Rename…", systemImage: "pencil") { onRename(game) }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete([game]) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete([game]) }
                            .tint(theme.colors.destructive)
                    }
                    .task(id: pixelWidth) { await loadCover(game, pixelWidth, displayScale) }
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("gameList")
    }

    @ViewBuilder private func row(_ game: LibraryEntry) -> some View {
        let content = GameRow(title: game.title, books: game.bookCountText, lastOpened: game.lastOpened,
                              cover: game.coverBook.flatMap { covers[$0.fileName] })
        if isSelecting {
            content
        } else {
            NavigationLink(value: GameRoute.game(id: game.id)) { content }
        }
    }
}

#Preview {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: LibraryFixtures.covers, selection: .constant([]),
                 loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
            .themeBackground(\.groupedBackground)
    }
    .themed()
}
#Preview("Selecting, two selected") {
    LibraryFixtures.selecting(selected: ["tile-garden.pdf", "woodland-court.pdf"]).themed()
}
#Preview("Dark") {
    NavigationStack {
        GameList(games: LibraryFixtures.games, covers: [:], selection: .constant([]), loadCover: { _, _, _ in }, onDelete: { _ in })
            .navigationTitle("My Games")
            .themeBackground(\.groupedBackground)
    }
    .themed()
    .preferredColorScheme(.dark)
}
