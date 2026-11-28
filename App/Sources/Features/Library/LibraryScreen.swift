import SwiftUI
import AckshuallyCore

/// Root of the app (S1 · My Games): the list of imported rulebooks in a `NavigationStack`;
/// a row pushes the viewer, whose Back returns here. The same stack on every size: on wide
/// screens the viewer already uses a trailing inspector column for the answer, so a
/// sidebar for the list would leave the PDF a third of the window (see m2-notes, My Games).
struct LibraryScreen: View {
    @Bindable var library: LibraryModel
    var voice: AskController
    @State private var importing = false
    @State private var settings = false
    @State private var windowSize = CGSize.zero
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<String>()
    /// Long press → Rename…: the game being renamed and the alert's text.
    @State private var renaming: LibraryEntry?
    @State private var isRenaming = false
    @State private var newName = ""
    /// Deletes register here: shake or three-finger swipe undoes them.
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationStack(path: $library.navigationPath) {
            content
                .undoBar(library)
                .navigationTitle("My Games")
                .toolbar {
                    LibraryToolbar(isSelecting: editMode.isEditing, selectedCount: selection.count,
                                   allSelected: !library.games.isEmpty && selection.count == library.games.count,
                                   canSelect: !library.games.isEmpty,
                                   onAdd: { importing = true }, onSettings: { settings = true },
                                   onToggleSelecting: toggleSelecting, onSelectAll: selectAll, onDeleteSelected: deleteSelected)
                }
                .environment(\.editMode, $editMode)
                .themeBackground(\.groupedBackground)
                .navigationDestination(for: GameRoute.self) { route in
                    ViewerScreen(model: library.session(for: route), voice: voice, windowSize: windowSize,
                                 title: library.playingTitle(for: route))
                }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { library.addRulebooks(urls) }
        }
        // On a Mac (Designed for iPad), PDFs dropped on My Games go the same way as ＋.
        .dropDestination(for: URL.self) { urls, _ in library.addRulebooks(urls) }
        .sheet(isPresented: $settings) {
            SettingsSheet { settings = false }
                .themed()
        }
        // S13: a game with add-ons asks what you play with before it opens.
        .sheet(item: $library.checklist) { c in
            PlayingWithScreen(gameID: c.id, purpose: .play) { library.checklist = nil }
                .presentationDetents([.medium, .large])
                .themed()
        }
        // S14: ＋ → "Add N Rulebooks".
        .addRulebooksSheet(library)
        .confirmationDialog(library.pendingDeletion?.question ?? "", item: $library.pendingDeletion, titleVisibility: .visible) { d in
            Button(d.confirmTitle, role: .destructive, action: confirmDeletion)
                .accessibilityIdentifier("confirmDelete")
        } message: { Text($0.detail) }
        .alert("Rename Game", isPresented: $isRenaming, presenting: renaming) { game in
            TextField("Name", text: $newName)
                .accessibilityIdentifier("renameGameField")
            Button("Cancel", role: .cancel) {}
            Button("Rename") { library.renameGame(game.id, to: newName) }
        }
        .environment(library)
    }

    private func confirmDeletion() {
        library.confirmDeletion(undoManager: undoManager)
        endSelecting()
    }

    private func rename(_ game: LibraryEntry) {
        renaming = game
        newName = game.title
        isRenaming = true
    }

    private func toggleSelecting() {
        if editMode.isEditing { endSelecting() } else { editMode = .active }
    }

    private func endSelecting() {
        editMode = .inactive
        selection = []
    }

    private func selectAll(_ all: Bool) {
        selection = all ? Set(library.games.map(\.id)) : []
    }

    /// One one-book game goes at once (undoable); otherwise the confirmation ends selecting.
    private func deleteSelected() {
        library.requestDelete(library.games.filter { selection.contains($0.id) }, undoManager: undoManager)
        if library.pendingDeletion == nil { endSelecting() }
    }

    @ViewBuilder private var content: some View {
        if !library.isLoaded {
            Color.clear
        } else if library.games.isEmpty {
            EmptyLibraryView(error: library.error, onAdd: { importing = true }, onSample: { library.addSample() })
        } else {
            GameList(games: library.games, covers: library.covers, selection: $selection,
                     loadCover: { await library.loadCover(for: $0, pixelWidth: $1, scale: $2) },
                     onOpen: { library.navigationPath = [.game(id: $0.id)] },
                     onRename: rename,
                     onDelete: { library.requestDelete($0, undoManager: undoManager) })
                .alert("Couldn't Open the Rulebook", item: $library.error) { _ in } message: { Text($0) }
        }
    }
}

#Preview("Games") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed() }
#Preview("Deleted, Undo bar") {
    let library = LibraryFixtures.model()
    library.delete([library.games[0]])
    return LibraryScreen(library: library, voice: AskController()).themed()
}
#Preview("Empty") { LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController()).themed() }
#Preview("Empty, dark") {
    LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController()).themed().preferredColorScheme(.dark)
}
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed()
}
#Preview("Landscape", traits: .landscapeLeft) { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed() }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().environment(\.horizontalSizeClass, .regular)
}
#Preview("AX5") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().preferredColorScheme(.dark) }
#Preview("Playing with") {
    let library = PlayingWithFixtures.library()
    library.checklist = .init(id: PlayingWithFixtures.sampleID)
    return LibraryScreen(library: library, voice: AskController()).themed()
}
