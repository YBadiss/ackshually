import UIKit
import Observation
import AckshuallyCore

/// My Games (S1): the persisted list of imported rulebooks, the navigation path into the viewer,
/// and the covers. Opening a game goes through here so the viewer and the list agree on what is
/// open; the viewer itself (`ViewerModel`) only loads files.
@MainActor
@Observable
final class LibraryModel {
    let viewer: ViewerModel
    private(set) var index: LibraryIndex
    private(set) var path: [GameRoute] = []
    private(set) var covers: [String: UIImage] = [:]
    /// Shown on the list (an import or open that failed).
    var error: String?
    /// Off for previews: nothing is written to disk.
    private let persists: Bool

    var games: [LibraryEntry] { index.entries }

    init(viewer: ViewerModel, index: LibraryIndex? = nil) {
        self.viewer = viewer
        self.persists = index == nil
        self.index = index ?? Library.loadIndex()
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

    /// Loads the route's file into the viewer unless it is already open there (back + tap the
    /// same game resumes the answer), and bumps the game to the top of the list.
    private func prepare(_ route: GameRoute) -> Bool {
        let url = url(for: route)
        if viewer.rulebook?.url.standardizedFileURL != url.standardizedFileURL {
            guard viewer.open(url) else {
                error = viewer.openError
                return false
            }
        }
        if case .game(let name) = route {
            index.markOpened(name)
            save()
        }
        error = nil
        return true
    }

    func url(for route: GameRoute) -> URL {
        switch route {
        case .game(let name): Library.url(for: name)
        case .file(let url): url
        }
    }

    // MARK: Adding

    /// "Add a Rulebook": copy the picked PDF into the library and open it right away.
    func importPicked(_ picked: URL) {
        do { add(try Library.importPDF(from: picked)) } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
    }

    /// "Try the Sample": the bundled Power Plant Rush, as a game in the list.
    func addSample() {
        do { add(try Library.sampleRulebook()) } catch { self.error = "\(error)" }
    }

    /// Adds the sample without opening it (`-seedSample YES`).
    func seedSample() {
        guard let url = try? Library.sampleRulebook() else { return }
        index.record(fileName: url.lastPathComponent, title: Library.title(of: url))
        save()
    }

    /// Opens a file that stays out of the library (launch arguments): Back returns to the list.
    func openTransient(_ url: URL) {
        guard viewer.open(url) else { error = viewer.openError; return }
        path = [.file(url)]
    }

    func openSampleTransient() {
        guard let url = try? Library.sampleRulebook() else { return }
        openTransient(url)
    }

    private func add(_ url: URL) {
        // Always reload: a re-import of the same file name replaces its contents.
        guard viewer.open(url), let rb = viewer.rulebook else { error = viewer.openError; return }
        index.record(fileName: url.lastPathComponent, title: rb.title)
        save()
        covers[url.lastPathComponent] = nil
        push(.game(fileName: url.lastPathComponent))
    }

    // MARK: Removing

    /// Swipe to delete: the entry, its imported copy and its covers.
    func delete(_ entries: [LibraryEntry]) {
        for e in entries {
            index.remove(e.fileName)
            covers[e.fileName] = nil
            let url = Library.url(for: e.fileName)
            if viewer.rulebook?.url.standardizedFileURL == url.standardizedFileURL { viewer.close() }
            if persists {
                Library.deleteFile(named: e.fileName)
                Task { await CoverCache.shared.remove(fileName: e.fileName) }
            }
        }
        save()
    }

    /// `-emptyLibrary YES`: start from no games.
    func reset() {
        if persists { index = Library.reset() } else { index = LibraryIndex() }
        covers = [:]
        viewer.close()
        path = []
    }

    // MARK: Covers

    /// Renders (or reads from cache) the first page at `pixelWidth`, off the main thread.
    func loadCover(for entry: LibraryEntry, pixelWidth: Int, scale: CGFloat) async {
        if let c = covers[entry.fileName], Int(c.size.width * c.scale) >= pixelWidth { return }
        let url = Library.url(for: entry.fileName)
        guard let img = await CoverCache.shared.cover(for: url, pixelWidth: pixelWidth),
              let cg = img.cgImage else { return }
        covers[entry.fileName] = UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    /// Previews: covers made up front.
    func setCover(_ image: UIImage, for fileName: String) { covers[fileName] = image }

    private func save() {
        if persists { Library.save(index) }
    }
}
