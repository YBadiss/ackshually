import SwiftUI

/// "Playing with" bound to the library (`LibraryModel`, from the environment so the viewer's dialogs, which
/// may be presented from inside the answer sheet, can show it too). Edits are saved as they happen; Play opens
/// the game, Done hands the open viewer its new books (they apply from the next question).
struct PlayingWithScreen: View {
    var gameID: String
    var purpose: PlayingWithContent.Purpose
    var onDismiss: () -> Void
    @Environment(LibraryModel.self) private var library: LibraryModel?
    @State private var importing = false
    /// Removals register here: shake or three-finger swipe undoes them.
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        if let library, let game = library.game(gameID) {
            PlayingWithSheet(
                content: PlayingWithContent(game, purpose: purpose, isOpening: library.opening == gameID),
                onToggle: { library.toggle($0, in: gameID) },
                onRemove: { library.removeBook($0, from: gameID, undoManager: undoManager) },
                onSetRole: { library.setRole($0, in: gameID, to: $1) },
                onRename: { library.renameBook($0, in: gameID, to: $1) },
                onRenameGame: { library.renameGame(gameID, to: $0) },
                onDeleteGame: {
                    library.deleteGame(gameID, undoManager: undoManager)
                    onDismiss()
                },
                onAdd: { importing = true },
                onConfirm: confirm,
                onClose: onDismiss)
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                    if case .success(let urls) = result { library.addRulebooks(urls, to: gameID) }
                }
                // S14 with this game suggested.
                .addRulebooksSheet(library, from: gameID)
                // "Removed Riverfolk · Undo" (#29: removing a book doesn't ask).
                .undoBar(library)
        } else {
            ContentUnavailableView("Game Removed", systemImage: "book.closed")
        }
    }

    private func confirm() {
        switch purpose {
        case .play:
            library?.play(gameID)
        case .change:
            library?.booksChanged(gameID)
            onDismiss()
        }
    }
}

#Preview("Play") {
    let library = PlayingWithFixtures.library()
    PlayingWithScreen(gameID: PlayingWithFixtures.sampleID, purpose: .play) {}
        .environment(library)
        .themed()
}
#Preview("From the viewer, dark") {
    let library = PlayingWithFixtures.library()
    PlayingWithScreen(gameID: PlayingWithFixtures.sampleID, purpose: .change) {}
        .environment(library)
        .themed()
        .preferredColorScheme(.dark)
}
#Preview("Removed, Undo bar") {
    let library = PlayingWithFixtures.library()
    library.removeBook(Library.sampleExpansionFileName, from: PlayingWithFixtures.sampleID)
    return PlayingWithScreen(gameID: PlayingWithFixtures.sampleID, purpose: .change) {}
        .environment(library)
        .themed()
}
