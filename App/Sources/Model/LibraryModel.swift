import UIKit
import Observation
import AckshuallyCore

/// My Games (S1) and the books of each game (S13): the persisted list of games, the navigation path into the
/// viewer, the covers, the "Playing with" list shown before a game with add-ons opens, the "Add N Rulebooks"
/// review of picked PDFs (S14), deletions waiting for a confirmation, deletions and removals that can still be undone
/// (their PDFs pending deletion until the app goes to the background), and one viewer session per open game. Opening a game creates its
/// `ViewerModel` (or brings back the one it had), so going back and re-opening a game keeps its answer; the last
/// `sessionLimit` games keep theirs, older ones are dropped to bound memory (each holds the PDF and a matcher).
@MainActor
@Observable
final class LibraryModel {
    static let sessionLimit = 3

    /// The "Playing with" list for a game about to open from My Games.
    struct Checklist: Identifiable, Equatable {
        var id: String
    }

    /// Games about to be deleted, waiting for "Delete Root and its 7 rulebooks?".
    struct Deletion: Identifiable, Equatable {
        var games: [LibraryEntry]
        var id: [String] { games.map(\.id) }
        var bookCount: Int { games.reduce(0) { $0 + $1.books.count } }

        /// "Delete Root and its 7 rulebooks?", "Delete 3 games and their 9 rulebooks?".
        var question: String {
            if games.count == 1 {
                let g = games[0]
                return g.books.count == 1 ? "Delete \(g.title)?" : "Delete \(g.title) and its \(g.books.count) rulebooks?"
            }
            return "Delete \(games.count) games and their \(bookCount) rulebooks?"
        }

        var detail: String { bookCount == 1 ? "The PDF is removed from this device." : "The PDFs are removed from this device." }

        /// The destructive button names the action: "Delete Game", "Delete 3 Games".
        var confirmTitle: String { games.count == 1 ? "Delete Game" : "Delete \(games.count) Games" }
    }

    private(set) var index: LibraryIndex
    private(set) var path: [GameRoute] = []
    /// Keyed by the cover book's file name.
    private(set) var covers: [String: UIImage] = [:]
    /// Viewer sessions, least recently opened first.
    private(set) var sessions: [ViewerModel] = []
    /// Shown on the list (an import or open that failed).
    var error: String?
    /// S13: a game with add-ons asks what you play with every time it is opened from My Games.
    var checklist: Checklist?
    /// S14: picked PDFs (copied, not in the index yet) grouped into games for review. Nothing is saved until Add.
    private(set) var review: ImportBatch?
    /// Asked before deleting (Edit → Delete, or a swipe on a game with several books).
    var pendingDeletion: Deletion?
    /// Deletions and removals that can still be undone (their PDFs are pending deletion), oldest first.
    private(set) var removals: [Removal] = []
    /// My Games' "Deleted Root · Undo" bar: the latest game deletion, until the next action or a timeout.
    private(set) var undoBar: Removal?
    /// The window's undo manager the removals were registered with, cleared when they're purged.
    @ObservationIgnored private weak var undoManager: UndoManager?
    /// A game whose books are being joined before it opens (its Play button shows progress).
    private(set) var opening: String?

    @ObservationIgnored private let storage: any LibraryStorage
    @ObservationIgnored private let providers: any AnswerProviderFactory
    @ObservationIgnored private let suggestions: any RulebookSuggestions
    @ObservationIgnored private var sortTask: Task<Void, Never>?
    /// What happens once the review sheet is gone (one sheet can't present while another dismisses).
    @ObservationIgnored private var afterReview: (@MainActor () -> Void)?

    /// False until the index is read; the list shows nothing (not "No Games Yet") until then.
    private(set) var isLoaded: Bool

    var games: [LibraryEntry] { index.entries }

    func game(_ id: String) -> LibraryEntry? { index.entry(id: id) }

    /// `loadIndex: false` starts empty: the app calls `load()`, which reads the index off the main
    /// thread, so launch does no file I/O before the first frame (with Xcode's debugger attached,
    /// each main-thread file call costs ~1 s of diagnostics: launch sat on a blank screen for 12 s).
    init(dependencies: AppDependencies, loadIndex: Bool = true) {
        storage = dependencies.library
        providers = dependencies.providers
        suggestions = dependencies.suggestions
        index = loadIndex ? dependencies.library.loadIndex() : LibraryIndex()
        isLoaded = loadIndex
    }

    /// Reads the saved index in the background, and deletes what the last run left pending deletion.
    func load() async {
        let storage = storage
        index = await Task.detached(priority: .userInitiated) { storage.loadIndex() }.value
        isLoaded = true
        await storage.purgePending()
    }

    // MARK: Sessions

    /// The session open for `route`, if any (the stack's destination reads it; it never creates one).
    func session(for route: GameRoute) -> ViewerModel? {
        sessions.first { $0.route == route }
    }

    /// The game on top of the stack.
    var current: ViewerModel? { path.last.flatMap(session(for:)) }

    private func keep(_ s: ViewerModel) {
        sessions.removeAll { $0 === s }
        sessions.append(s)
        if sessions.count > Self.sessionLimit { sessions.removeFirst(sessions.count - Self.sessionLimit) }
    }

    private func newSession(_ rb: LoadedRulebook, route: GameRoute) -> ViewerModel {
        sessions.removeAll { $0.route == route }
        let s = ViewerModel(rulebook: rb, providers: providers, route: route)
        keep(s)
        return s
    }

    /// A file that stays out of the library (launch arguments).
    private func openFile(_ url: URL) -> ViewerModel? {
        if let s = session(for: .file(url)) { keep(s); return s }
        guard let rb = LoadedRulebook(url: url) else {
            error = "Couldn't open \(url.lastPathComponent) as a PDF."
            return nil
        }
        return newSession(rb, route: .file(url))
    }

    // MARK: Navigation

    /// The stack's path (`$library.navigationPath`): a row's `NavigationLink(value:)` pushes `.game`, which
    /// opens it first; Back pops. A game with add-ons shows "Playing with" instead of pushing (Play pushes).
    var navigationPath: [GameRoute] {
        get { path }
        set {
            guard let top = newValue.last, top != path.last else { path = newValue; return }
            if prepare(top) { path = newValue }
        }
    }

    /// True when `route` can be pushed right away.
    private func prepare(_ route: GameRoute) -> Bool {
        error = nil
        undoBar = nil
        switch route {
        case .file(let url):
            return openFile(url) != nil
        case .game(let id):
            guard let game = index.entry(id: id) else { return false }
            if game.hasAddOns {
                checklist = Checklist(id: id)
                return false
            }
            return open(game)
        }
    }

    /// Opens `game` with its books in play. True when it is ready now (one book, or its session is still
    /// open); several books not loaded yet are joined in the background and pushed when ready.
    @discardableResult
    private func open(_ game: LibraryEntry) -> Bool {
        let route = GameRoute.game(id: game.id)
        if let s = session(for: route) {
            keep(s)
            restage(s, for: game)
            markOpened(game.id)
            return true
        }
        guard game.booksInPlay.count > 1 else {
            guard let rb = storage.load(game) else {
                error = "Couldn't open \(game.title) as a PDF."
                return false
            }
            _ = newSession(rb, route: route)
            markOpened(game.id)
            return true
        }
        Task { await openInBackground(game) }
        return false
    }

    private func openInBackground(_ game: LibraryEntry) async {
        guard opening == nil else { return }
        opening = game.id
        defer { opening = nil }
        let storage = storage
        let rb = await Task.detached(priority: .userInitiated) { storage.load(game) }.value
        guard let rb else {
            error = "Couldn't open the rulebooks of \(game.title)."
            return
        }
        _ = newSession(rb, route: .game(id: game.id))
        markOpened(game.id)
        checklist = nil
        path = [.game(id: game.id)]
    }

    /// An open session whose books in play changed (ticks, roles, names, removed books) gets the new set; it
    /// applies from its next question (`AnswerSession.stage`).
    private func restage(_ s: ViewerModel, for game: LibraryEntry) {
        let signature = Library.signature(of: game)
        guard s.session.rulebook.signature != signature, s.stagedSignature != signature else { return }
        s.stagedSignature = signature
        let storage = storage
        s.session.stage(Task.detached(priority: .userInitiated) { storage.load(game) })
    }

    private func markOpened(_ id: String) {
        index.markOpened(id)
        storage.save(index)
    }

    func url(for fileName: String) -> URL { storage.url(for: fileName) }

    // MARK: Playing with (S13)

    /// "Play" on the list shown before the game opens: open it with the ticked books.
    func play(_ id: String) {
        guard let game = index.entry(id: id) else { checklist = nil; return }
        if open(game) {
            checklist = nil
            path = [.game(id: id)]
        }
    }

    /// The list was closed from the viewer (title button): the open session picks up the change.
    func booksChanged(_ id: String) {
        guard let game = index.entry(id: id), let s = session(for: .game(id: id)) else { return }
        restage(s, for: game)
    }

    /// "Root · Riverfolk, Rootbotics": the viewer's title button.
    func playingTitle(for route: GameRoute) -> String? {
        guard case .game(let id) = route, let game = index.entry(id: id) else { return nil }
        return game.playingTitle
    }

    func toggle(_ fileName: String, in id: String) {
        guard let b = index.entry(id: id)?.book(fileName) else { return }
        index.setTicked(fileName, in: id, !b.ticked)
        storage.save(index)
    }

    func setRole(_ fileName: String, in id: String, to role: BookRole) {
        index.setRole(fileName, in: id, to: role)
        storage.save(index)
    }

    func renameBook(_ fileName: String, in id: String, to title: String) {
        index.renameBook(fileName, in: id, to: title)
        storage.save(index)
    }

    func renameGame(_ id: String, to title: String) {
        index.renameGame(id, to: title)
        storage.save(index)
    }

    /// Swipe → Remove: the book leaves the game and, once purged, the device (not the game's last core book).
    /// Undoable until then.
    func removeBook(_ fileName: String, from id: String, undoManager: UndoManager? = nil) {
        guard let game = index.entry(id: id), let position = game.books.firstIndex(where: { $0.fileName == fileName }),
              index.removeBook(fileName, from: id) else { return }
        storage.save(index)
        var removal = Removal(kind: .book(game.books[position], gameID: id, position: position))
        removal.covers[fileName] = covers.removeValue(forKey: fileName)
        storage.moveToPending(fileName: fileName)
        remember(removal, undoManager: undoManager, showsBar: false)
    }

    /// Remove on a game's only book, after "Delete <game>?" (S13): the game goes with it.
    func deleteGame(_ id: String, undoManager: UndoManager? = nil) {
        guard let game = index.entry(id: id) else { return }
        delete([game], undoManager: undoManager)
    }

    /// A book added to "Root" named "Root Riverfolk" is shown as "Riverfolk" (the game's name is implied).
    static func bookTitle(_ title: String, in game: LibraryEntry) -> String {
        let name = game.title
        // "Root Riverfolk", "Root: Underworld", "Root - FAQ"; not "Rootbotics".
        guard title.count > name.count, title.lowercased().hasPrefix(name.lowercased()),
              let next = title.dropFirst(name.count).first, !next.isLetter, !next.isNumber else { return title }
        let rest = title.dropFirst(name.count).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return rest.isEmpty ? title : rest.prefix(1).uppercased() + rest.dropFirst()
    }

    // MARK: Adding

    /// ＋ (My Games, or a game's "Playing with" with `gameID`), or PDFs dropped on My Games: copy them into the
    /// library folder and open the review (S14) at once, every file under "Sorting…". The suggestion then
    /// groups them; with no server route, or when it fails, each file stays its own game ("Sort these yourself").
    func addRulebooks(_ picked: [URL], to gameID: String? = nil) {
        guard review == nil else { return }
        error = nil
        undoBar = nil
        let target = gameID.flatMap { index.entry(id: $0) }
        var copied: [(fileName: String, title: String)] = []
        for url in picked where url.pathExtension.lowercased() == "pdf" {
            do {
                let copy = try storage.importPDF(from: url)
                let title = storage.title(of: copy)
                copied.append((copy.lastPathComponent, target.map { Self.bookTitle(title, in: $0) } ?? title))
            } catch {
                self.error = "Import failed: \(error.localizedDescription)"
            }
        }
        guard !copied.isEmpty else { return }
        review = ImportBatch(files: copied, preferredGameID: target?.id)
        sortTask = Task { await sortReview() }
    }

    private func sortReview() async {
        guard let batch = review else { return }
        let games = index.entries
        guard suggestions.isAvailable else {
            review?.leaveUnsorted(games: games)
            return
        }
        let storage = storage
        let names = batch.sorting.map(\.fileName)
        let files = await Task.detached(priority: .userInitiated) {
            names.compactMap { RulebookSorter.File(fileName: $0, url: storage.url(for: $0)) }
        }.value
        let result: [RulebookSorter.Suggestion]?
        do {
            result = try await suggestions.suggest(files, games: games.map(RulebookSorter.Game.init),
                                                   preferredGameID: batch.preferredGameID)
        } catch {
            result = nil
        }
        guard !Task.isCancelled, review != nil else { return }
        if let result { review?.apply(result, games: index.entries) } else { review?.leaveUnsorted(games: index.entries) }
    }

    // Review edits (S14).
    func moveBook(_ fileName: String, toGroup id: String, before: String? = nil) { review?.move(fileName, toGroup: id, before: before) }
    func moveBook(_ fileName: String, toGame id: String) {
        guard let game = index.entry(id: id) else { return }
        review?.move(fileName, toGame: game)
    }
    func moveBookToNewGame(_ fileName: String) { review?.moveToNewGame(fileName) }
    func skipBook(_ fileName: String) { review?.skip(fileName) }
    func setReviewRole(_ fileName: String, _ role: BookRole) { review?.setRole(fileName, role) }
    func renameReviewBook(_ fileName: String, to title: String) { review?.renameBook(fileName, to: title) }
    func renameReviewGroup(_ id: String, to name: String) { review?.renameGroup(id, to: name) }

    /// Add: the groups go into the library; skipped copies are removed. One new game from My Games opens
    /// (its "Playing with" first if it has add-ons); otherwise the sheet just closes.
    func confirmReview() {
        guard let batch = review, !batch.isSorting else { return }
        sortTask?.cancel()
        let created = index.add(batch)
        storage.save(index)
        for id in batch.groups.compactMap({ if case .existing(let id) = $0.target { id } else { nil } }) {
            if let s = session(for: .game(id: id)), let game = index.entry(id: id) { restage(s, for: game) }
        }
        let storage = storage
        for b in batch.skipped { Task { await storage.delete(fileName: b.fileName) } }
        review = nil
        if batch.preferredGameID == nil, created.count == 1, batch.groups.count == 1, let id = created.first {
            afterReview = { [weak self] in self?.openAdded(id) }
        }
    }

    /// Cancel: every copy is removed again.
    func cancelReview() {
        guard let batch = review else { return }
        sortTask?.cancel()
        review = nil
        afterReview = nil
        let storage = storage
        for name in batch.fileNames { Task { await storage.delete(fileName: name) } }
    }

    func reviewDismissed() {
        let next = afterReview
        afterReview = nil
        next?()
    }

    /// A new game just added: open it, or show its "Playing with" first.
    private func openAdded(_ id: String) {
        guard let game = index.entry(id: id) else { return }
        if game.hasAddOns {
            checklist = Checklist(id: id)
        } else if open(game) {
            path = [.game(id: id)]
        }
    }

    /// "Try the Sample": the bundled Power Plant Rush, as a game in the list.
    func addSample() {
        do { addNewGame(try storage.sampleRulebook()) } catch { self.error = "\(error)" }
    }

    /// Adds the sample without opening it (`-seedSample YES`).
    func seedSample() {
        guard let url = try? storage.sampleRulebook() else { return }
        index.record(fileName: url.lastPathComponent, title: storage.title(of: url))
        storage.save(index)
    }

    /// The sample plus its made-up Solar Expansion as an add-on (`-seedSampleSet YES`, S13 screenshots).
    func seedSampleSet() {
        guard let url = try? storage.sampleRulebook(), let solar = try? storage.sampleExpansion() else { return }
        let id = url.lastPathComponent
        index.record(fileName: id, title: storage.title(of: url))
        index.addBook(LibraryBook(fileName: solar.lastPathComponent, title: "Solar Expansion", role: .addOn, ticked: true), to: id)
        storage.save(index)
    }

    /// Opens a file that stays out of the library (launch arguments): Back returns to the list.
    func openTransient(_ url: URL) {
        guard openFile(url) != nil else { return }
        path = [.file(url)]
    }

    func openSampleTransient() {
        guard let url = try? storage.sampleRulebook() else { return }
        openTransient(url)
    }

    private func addNewGame(_ url: URL) {
        let name = url.lastPathComponent
        index.record(fileName: name, title: storage.title(of: url))
        storage.save(index)
        covers[name] = nil
        // Always reload: a re-import of the same file replaces its contents (and its conversation).
        sessions.removeAll { $0.route == .game(id: name) }
        guard let game = index.entry(id: name), open(game) else { return }
        path = [.game(id: name)]
    }

    // MARK: Removing

    /// Swipe → Delete or Edit → Delete: a single game with one book goes at once (undoable); several games, or a
    /// game with several books, wait for a confirmation (`pendingDeletion`).
    func requestDelete(_ entries: [LibraryEntry], undoManager: UndoManager? = nil) {
        guard !entries.isEmpty else { return }
        if entries.count == 1, entries[0].books.count == 1 {
            delete(entries, undoManager: undoManager)
        } else {
            pendingDeletion = Deletion(games: entries)
        }
    }

    func confirmDeletion(undoManager: UndoManager? = nil) {
        guard let d = pendingDeletion else { return }
        pendingDeletion = nil
        delete(d.games, undoManager: undoManager)
    }

    /// The games leave the list with their session and their place on the stack; their PDFs wait in the
    /// pending-deletion folder, so the delete can be undone until the app goes to the background.
    func delete(_ entries: [LibraryEntry], undoManager: UndoManager? = nil) {
        let removed = index.remove(entries.map(\.id))
        guard !removed.isEmpty else { return }
        storage.save(index)
        var removal = Removal(kind: .games(removed))
        for name in removal.fileNames {
            removal.covers[name] = covers.removeValue(forKey: name)
            storage.moveToPending(fileName: name)
        }
        forget(removed)
        remember(removal, undoManager: undoManager, showsBar: true)
    }

    /// Settings → Developer → Remove All Games (after its confirmation): at once, not undoable.
    func removeAllGames() {
        let games = index.removeAll()
        forget(games)
        storage.save(index)
        let storage = storage
        for b in games.flatMap(\.books) {
            covers[b.fileName] = nil
            Task { await storage.delete(fileName: b.fileName) }
        }
    }

    private func forget(_ games: [LibraryEntry]) {
        let ids = Set(games.map(\.id))
        sessions.removeAll { if case .game(let id) = $0.route { ids.contains(id) } else { false } }
        path.removeAll { if case .game(let id) = $0 { ids.contains(id) } else { false } }
        if let c = checklist, ids.contains(c.id) { checklist = nil }
    }

    // MARK: Undo

    private func remember(_ removal: Removal, undoManager: UndoManager?, showsBar: Bool) {
        removals.append(removal)
        if showsBar { undoBar = removal }
        guard let undoManager else { return }
        self.undoManager = undoManager
        let id = removal.id
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.undoRemoval(id) }
        }
        undoManager.setActionName(removal.actionName)
    }

    /// Undo on My Games' bar.
    func undo(_ removal: Removal) {
        undoRemoval(removal.id)
    }

    /// Puts the games back where they were in the list (it's ordered by last opened), or the book back in its
    /// place in its game, with their files and covers. Nothing happens once purged, or if the game a book
    /// came from is gone, or a new import took one of the file names.
    private func undoRemoval(_ id: UUID) {
        guard let i = removals.firstIndex(where: { $0.id == id }) else { return }
        let removal = removals[i]
        switch removal.kind {
        case .games(let games):
            guard games.allSatisfy({ index.entry(id: $0.id) == nil }),
                  storage.restoreFromPending(fileNames: removal.fileNames) else { return }
            index = LibraryIndex(entries: index.entries + games)
        case .book(let book, let gameID, let position):
            guard var game = index.entry(id: gameID), game.book(book.fileName) == nil,
                  storage.restoreFromPending(fileNames: removal.fileNames) else { return }
            game.books.insert(book, at: min(position, game.books.count))
            index = LibraryIndex(entries: index.entries.filter { $0.id != gameID } + [game])
            if let s = session(for: .game(id: gameID)) { restage(s, for: game) }
        }
        storage.save(index)
        removals.remove(at: i)
        if undoBar?.id == id { undoBar = nil }
        covers.merge(removal.covers) { current, _ in current }
    }

    /// The bar timed out (or `removal` is no longer the latest): it goes, the undo stays.
    func dismissUndoBar(_ removal: Removal? = nil) {
        guard removal == nil || undoBar?.id == removal?.id else { return }
        undoBar = nil
    }

    /// The app went to the background: pending files are deleted and nothing can be undone any more.
    func purgeRemovals() async {
        removals = []
        undoBar = nil
        undoManager?.removeAllActions(withTarget: self)
        await storage.purgePending()
    }

    /// `-emptyLibrary YES`: start from no games.
    func reset() {
        index = storage.reset()
        removals = []
        undoBar = nil
        covers = [:]
        sessions = []
        path = []
    }

    // MARK: Covers

    /// Renders (or reads from cache) the cover book's first page at `pixelWidth`, off the main thread.
    func loadCover(for entry: LibraryEntry, pixelWidth: Int, scale: CGFloat) async {
        guard let file = entry.coverBook?.fileName else { return }
        await loadCover(fileName: file, pixelWidth: pixelWidth, scale: scale)
    }

    /// Any book's first page (the review's thumbnails, S14).
    func loadCover(fileName file: String, pixelWidth: Int, scale: CGFloat) async {
        if let c = covers[file], Int(c.size.width * c.scale) >= pixelWidth { return }
        guard let img = await storage.cover(for: storage.url(for: file), pixelWidth: pixelWidth),
              let cg = img.cgImage else { return }
        covers[file] = UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    /// Previews: covers made up front.
    func setCover(_ image: UIImage, for fileName: String) { covers[fileName] = image }
}
