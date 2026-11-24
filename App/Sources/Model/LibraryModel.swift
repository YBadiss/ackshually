import UIKit
import Observation
import AckshuallyCore

/// My Games (S1) and the books of each game (S13): the persisted list of games, the navigation path into the
/// viewer, the covers, the "Playing with" list shown before a game with add-ons opens, the choice a picked PDF
/// waits for (New Game or Add to a game), and one viewer session per open game. Opening a game creates its
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

    /// A picked PDF, already copied into the library, waiting for New Game / Add to a game.
    struct PendingImport: Identifiable, Equatable {
        var fileName: String
        var title: String
        var id: String { fileName }
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
    /// "Add a Rulebook" picked a PDF: New Game, or Add to a game (as core or add-on). The app never guesses.
    var pendingImport: PendingImport?
    /// A game whose books are being joined before it opens (its Play button shows progress).
    private(set) var opening: String?

    @ObservationIgnored private let storage: any LibraryStorage
    @ObservationIgnored private let providers: any AnswerProviderFactory

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
        index = loadIndex ? dependencies.library.loadIndex() : LibraryIndex()
        isLoaded = loadIndex
    }

    /// Reads the saved index in the background.
    func load() async {
        let storage = storage
        index = await Task.detached(priority: .userInitiated) { storage.loadIndex() }.value
        isLoaded = true
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

    /// Swipe → Remove: the book leaves the game and the device (not the game's last core book).
    func removeBook(_ fileName: String, from id: String) {
        guard index.removeBook(fileName, from: id) else { return }
        storage.save(index)
        covers[fileName] = nil
        let storage = storage
        Task { await storage.delete(fileName: fileName) }
    }

    /// ＋ Add a Rulebook in "Playing with": an add-on of this game, ticked.
    func addBook(picked: URL, to id: String) {
        guard let game = index.entry(id: id) else { return }
        do {
            let url = try storage.importPDF(from: picked)
            index.addBook(LibraryBook(fileName: url.lastPathComponent, title: Self.bookTitle(storage.title(of: url), in: game),
                                      role: .addOn, ticked: true), to: id)
            storage.save(index)
        } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
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

    /// "Add a Rulebook": copy the picked PDF into the library. With no games yet it is a new game, opened right
    /// away; otherwise the user says where it goes (New Game, or Add to a game as core or add-on).
    func importPicked(_ picked: URL) {
        do {
            let url = try storage.importPDF(from: picked)
            if index.isEmpty {
                addNewGame(url)
            } else {
                pendingImport = PendingImport(fileName: url.lastPathComponent, title: storage.title(of: url))
            }
        } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
    }

    /// New Game: the picked book on its own, opened right away (S2).
    func importAsNewGame() {
        guard let p = pendingImport else { return }
        pendingImport = nil
        addNewGame(storage.url(for: p.fileName))
    }

    /// Add to <game>, as a core book or an add-on (ticked). That game's "Playing with" list follows, once the
    /// import sheet is gone (`importSheetDismissed`: one sheet can't present while another dismisses).
    func importInto(_ id: String, as role: BookRole) {
        guard let p = pendingImport, let game = index.entry(id: id) else { return }
        pendingImport = nil
        index.addBook(LibraryBook(fileName: p.fileName, title: Self.bookTitle(p.title, in: game), role: role, ticked: true), to: id)
        storage.save(index)
        checklistAfterImport = id
    }

    /// The game whose list shows after the import sheet closes.
    private(set) var checklistAfterImport: String?

    func importSheetDismissed() {
        guard let id = checklistAfterImport else { return }
        checklistAfterImport = nil
        checklist = Checklist(id: id)
    }

    /// Cancel: the copy is removed again.
    func cancelImport() {
        guard let p = pendingImport else { return }
        pendingImport = nil
        let storage = storage
        Task { await storage.delete(fileName: p.fileName) }
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

    /// Swipe to delete: the game, every one of its books' copies and covers, and its session.
    func delete(_ entries: [LibraryEntry]) {
        for e in entries {
            index.remove(e.id)
            sessions.removeAll { $0.route == .game(id: e.id) }
            for b in e.books {
                covers[b.fileName] = nil
                let storage = storage
                Task { await storage.delete(fileName: b.fileName) }
            }
        }
        storage.save(index)
    }

    /// `-emptyLibrary YES`: start from no games.
    func reset() {
        index = storage.reset()
        covers = [:]
        sessions = []
        path = []
    }

    // MARK: Covers

    /// Renders (or reads from cache) the cover book's first page at `pixelWidth`, off the main thread.
    func loadCover(for entry: LibraryEntry, pixelWidth: Int, scale: CGFloat) async {
        guard let file = entry.coverBook?.fileName else { return }
        if let c = covers[file], Int(c.size.width * c.scale) >= pixelWidth { return }
        guard let img = await storage.cover(for: storage.url(for: file), pixelWidth: pixelWidth),
              let cg = img.cgImage else { return }
        covers[file] = UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    /// Previews: covers made up front.
    func setCover(_ image: UIImage, for fileName: String) { covers[fileName] = image }
}
