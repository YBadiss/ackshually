import SwiftUI
import AckshuallyCore

/// S13 · Playing with: the game's rulebooks, core books (always on) and add-ons ticked for tonight. Shown every
/// time a game with add-ons is opened from My Games (Play opens it) and from the viewer's title (Done).
/// Swipe left on a book → Remove (the game's only book: delete the game?); long-press → Make Core / Make Add-on,
/// Rename; ＋ Add Rulebooks at the bottom (S14, this game suggested).
struct PlayingWithSheet: View {
    var content: PlayingWithContent
    var onToggle: (String) -> Void
    var onRemove: (String) -> Void
    var onSetRole: (String, BookRole) -> Void
    var onRename: (String, String) -> Void
    var onRenameGame: (String) -> Void
    /// Remove on the game's only book, confirmed: the game goes.
    var onDeleteGame: () -> Void = {}
    var onAdd: () -> Void
    /// Play (from My Games) or Done (from the viewer).
    var onConfirm: () -> Void
    /// Close without playing (My Games only).
    var onClose: () -> Void
    @Environment(\.theme) private var theme
    @State private var renaming: Renaming?
    @State private var newName = ""
    @State private var confirmingDeleteGame = false

    /// What the rename alert renames.
    private enum Renaming: Equatable {
        case game
        case book(String)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(content.core) { row($0) }
                } header: {
                    Text("Core")
                } footer: {
                    Text("Always in play.")
                }
                .listRowBackground(theme.colors.card)
                if !content.addOns.isEmpty {
                    Section {
                        ForEach(content.addOns) { row($0) }
                    } header: {
                        Text("Add-ons")
                    } footer: {
                        Text("Tick what's on the table tonight. Answers only use the ticked books.")
                    }
                    .listRowBackground(theme.colors.card)
                }
                Section {
                    Button("Add Rulebooks", systemImage: "plus", action: onAdd)
                        .accessibilityIdentifier("addBook")
                } footer: {
                    Text("Add expansions, FAQs or errata. Long-press a book to rename it or make it core or an add-on.")
                }
                .listRowBackground(theme.colors.card)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.groupedBackground)
            .navigationTitle(content.gameTitle)
            .navigationSubtitle("Playing with")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                Button("Rename Game", systemImage: "pencil") { startRenaming(.game, current: content.gameTitle) }
            }
            .toolbar { toolbar }
            .alert("Delete \(content.gameTitle)?", isPresented: $confirmingDeleteGame) {
                Button("Delete Game", role: .destructive, action: onDeleteGame)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It's this game's only rulebook. The game and its PDF are removed from this device.")
            }
            .alert(renameTitle, item: $renaming) { target in
                TextField("Name", text: $newName)
                Button("Rename") { rename(target) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .accessibilityIdentifier("playingWith")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if content.purpose == .play {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark", role: .close, action: onClose)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            if content.isOpening {
                ProgressView().accessibilityLabel("Opening the rulebooks")
            } else {
                Button(content.purpose == .play ? "Play" : "Done", role: .confirm, action: onConfirm)
                    .accessibilityIdentifier("playingWithConfirm")
            }
        }
    }

    private func row(_ book: PlayingWithContent.Book) -> some View {
        BookRow(book: book) { onToggle(book.fileName) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if book.isOnlyBook {
                    Button("Remove", systemImage: "trash") { confirmingDeleteGame = true }
                        .tint(theme.colors.warning)
                } else if !book.isLastCore {
                    Button("Remove", systemImage: "trash", role: .destructive) { onRemove(book.fileName) }
                }
            }
            .contextMenu {
                if book.role == .addOn {
                    Button("Make Core", systemImage: "books.vertical") { onSetRole(book.fileName, .core) }
                } else if !book.isLastCore {
                    Button("Make Add-on", systemImage: "puzzlepiece.extension") { onSetRole(book.fileName, .addOn) }
                }
                Button("Rename", systemImage: "pencil") { startRenaming(.book(book.fileName), current: book.title) }
            }
    }

    private var renameTitle: String {
        renaming == .game ? "Rename Game" : "Rename Rulebook"
    }

    private func startRenaming(_ target: Renaming, current: String) {
        newName = current
        renaming = target
    }

    private func rename(_ target: Renaming) {
        switch target {
        case .game: onRenameGame(newName)
        case .book(let file): onRename(file, newName)
        }
    }
}

#Preview("Play") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PlayingWithFixtures.sheet(PlayingWithFixtures.content).themed().presentationDetents([.medium, .large])
    }
}
#Preview("From the viewer, one book") { PlayingWithFixtures.sheet(PlayingWithFixtures.oneBook).themed() }
#Preview("Opening") { PlayingWithFixtures.sheet(PlayingWithFixtures.opening).themed() }
#Preview("AX5") { PlayingWithFixtures.sheet(PlayingWithFixtures.content).themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { PlayingWithFixtures.sheet(PlayingWithFixtures.content).themed().preferredColorScheme(.dark) }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    PlayingWithFixtures.sheet(PlayingWithFixtures.content).themed().environment(\.horizontalSizeClass, .regular)
}
#Preview("Landscape", traits: .landscapeLeft) { PlayingWithFixtures.sheet(PlayingWithFixtures.content).themed() }
