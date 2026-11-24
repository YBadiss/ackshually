import UIKit
import Observation
import AckshuallyCore

/// My Games (S1): the persisted list of imported rulebooks, the navigation path into the viewer, the covers,
/// and one viewer session per open game. Opening a game creates its `ViewerModel` (or brings back the one
/// it had), so going back and re-opening a game keeps its answer; the last `sessionLimit` games keep theirs,
/// older ones are dropped to bound memory (each holds the PDF and a matcher).
@MainActor
@Observable
final class LibraryModel {
    static let sessionLimit = 3

    private(set) var index: LibraryIndex
    private(set) var path: [GameRoute] = []
    private(set) var covers: [String: UIImage] = [:]
    /// Viewer sessions, least recently opened first.
    private(set) var sessions: [ViewerModel] = []
    /// Shown on the list (an import or open that failed).
    var error: String?

    @ObservationIgnored private let storage: any LibraryStorage
    @ObservationIgnored private let providers: any AnswerProviderFactory

    /// False until the index is read; the list shows nothing (not "No Games Yet") until then.
    private(set) var isLoaded: Bool

    var games: [LibraryEntry] { index.entries }

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
        let url = url(for: route).standardizedFileURL
        return sessions.first { $0.rulebook.url.standardizedFileURL == url }
    }

    /// The game on top of the stack.
    var current: ViewerModel? { path.last.flatMap(session(for:)) }

    /// The session for `url`: the existing one (moved to most recent) unless `reload`, else a new one.
    private func openSession(_ url: URL, reload: Bool = false) -> ViewerModel? {
        let key = url.standardizedFileURL
        if let i = sessions.firstIndex(where: { $0.rulebook.url.standardizedFileURL == key }) {
            let s = sessions.remove(at: i)
            if !reload {
                sessions.append(s)
                return s
            }
        }
        guard let rb = LoadedRulebook(url: url) else {
            error = "Couldn't open \(url.lastPathComponent) as a PDF."
            return nil
        }
        let s = ViewerModel(rulebook: rb, providers: providers)
        sessions.append(s)
        if sessions.count > Self.sessionLimit { sessions.removeFirst(sessions.count - Self.sessionLimit) }
        return s
    }

    private func closeSessions(at url: URL) {
        let key = url.standardizedFileURL
        sessions.removeAll { $0.rulebook.url.standardizedFileURL == key }
    }

    // MARK: Navigation

    /// The stack's path (`$library.navigationPath`): a row's `NavigationLink(value:)` pushes
    /// `.game`, which opens it first; Back pops.
    var navigationPath: [GameRoute] {
        get { path }
        set {
            guard let top = newValue.last, top != path.last else { path = newValue; return }
            if prepare(top) { path = newValue }
        }
    }

    private func push(_ route: GameRoute) {
        if prepare(route) { path = [route] }
    }

    /// Opens the route's session (back + tap the same game resumes its answer) and bumps the game to the top
    /// of the list.
    private func prepare(_ route: GameRoute) -> Bool {
        guard openSession(url(for: route)) != nil else { return false }
        if case .game(let name) = route {
            index.markOpened(name)
            storage.save(index)
        }
        error = nil
        return true
    }

    func url(for route: GameRoute) -> URL {
        switch route {
        case .game(let name): storage.url(for: name)
        case .file(let url): url
        }
    }

    // MARK: Adding

    /// "Add a Rulebook": copy the picked PDF into the library and open it right away.
    func importPicked(_ picked: URL) {
        do { add(try storage.importPDF(from: picked)) } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
    }

    /// "Try the Sample": the bundled Power Plant Rush, as a game in the list.
    func addSample() {
        do { add(try storage.sampleRulebook()) } catch { self.error = "\(error)" }
    }

    /// Adds the sample without opening it (`-seedSample YES`).
    func seedSample() {
        guard let url = try? storage.sampleRulebook() else { return }
        index.record(fileName: url.lastPathComponent, title: storage.title(of: url))
        storage.save(index)
    }

    /// Opens a file that stays out of the library (launch arguments): Back returns to the list.
    func openTransient(_ url: URL) {
        guard openSession(url) != nil else { return }
        path = [.file(url)]
    }

    func openSampleTransient() {
        guard let url = try? storage.sampleRulebook() else { return }
        openTransient(url)
    }

    private func add(_ url: URL) {
        // Always reload: a re-import of the same file name replaces its contents (and its conversation).
        guard let session = openSession(url, reload: true) else { return }
        index.record(fileName: url.lastPathComponent, title: session.rulebook.title)
        storage.save(index)
        covers[url.lastPathComponent] = nil
        push(.game(fileName: url.lastPathComponent))
    }

    // MARK: Removing

    /// Swipe to delete: the entry, its imported copy, its covers and its session.
    func delete(_ entries: [LibraryEntry]) {
        for e in entries {
            index.remove(e.fileName)
            covers[e.fileName] = nil
            closeSessions(at: storage.url(for: e.fileName))
            let storage = storage
            Task { await storage.delete(fileName: e.fileName) }
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

    /// Renders (or reads from cache) the first page at `pixelWidth`, off the main thread.
    func loadCover(for entry: LibraryEntry, pixelWidth: Int, scale: CGFloat) async {
        if let c = covers[entry.fileName], Int(c.size.width * c.scale) >= pixelWidth { return }
        guard let img = await storage.cover(for: storage.url(for: entry.fileName), pixelWidth: pixelWidth),
              let cg = img.cgImage else { return }
        covers[entry.fileName] = UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    /// Previews: covers made up front.
    func setCover(_ image: UIImage, for fileName: String) { covers[fileName] = image }
}
