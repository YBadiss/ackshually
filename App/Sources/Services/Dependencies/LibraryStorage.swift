import UIKit
import AckshuallyCore

/// The files behind My Games: the index, the imported PDFs, the joined documents of games with several books
/// in play, and the covers. Live: `FileLibraryStorage` (Application Support/Rulebooks, Caches/Joined,
/// `CoverCache`); previews and tests: `InMemoryLibraryStorage`.
protocol LibraryStorage: Sendable {
    func loadIndex() -> LibraryIndex
    func save(_ index: LibraryIndex)
    /// Empties My Games: the index and every imported copy.
    func reset() -> LibraryIndex
    func url(for fileName: String) -> URL
    /// Copies a picked (security-scoped) file into the library under a name no other book has; returns the copy.
    func importPDF(from picked: URL) throws -> URL
    /// The document for a game's books in play (joined and cached when there are several). Slow the first
    /// time a set is joined: call it off the main thread.
    func load(_ game: LibraryEntry) -> LoadedRulebook?
    /// The sample rulebook inside the library folder (written on first use).
    func sampleRulebook() throws -> URL
    /// The sample's made-up add-on, Solar Expansion (written on first use).
    func sampleExpansion() throws -> URL
    /// Removes the imported copy and its cached covers.
    func delete(fileName: String) async
    func title(of url: URL) -> String
    /// The first page `pixelWidth` pixels wide (scale 1), rendered off the main thread.
    func cover(for url: URL, pixelWidth: Int) async -> UIImage?
}

struct FileLibraryStorage: LibraryStorage {
    func loadIndex() -> LibraryIndex { Library.loadIndex() }
    func save(_ index: LibraryIndex) { Library.save(index) }
    func reset() -> LibraryIndex { Library.reset() }
    func url(for fileName: String) -> URL { Library.url(for: fileName) }
    func importPDF(from picked: URL) throws -> URL { try Library.importPDF(from: picked) }
    func load(_ game: LibraryEntry) -> LoadedRulebook? { Library.load(game, url: Library.url(for:), joined: Library.joinedFolder) }
    func sampleRulebook() throws -> URL { try Library.sampleRulebook() }
    func sampleExpansion() throws -> URL { try Library.sampleExpansion() }
    func title(of url: URL) -> String { Library.title(of: url) }

    func delete(fileName: String) async {
        Library.deleteFile(named: fileName)
        await CoverCache.shared.remove(fileName: fileName)
    }

    func cover(for url: URL, pixelWidth: Int) async -> UIImage? {
        await CoverCache.shared.cover(for: url, pixelWidth: pixelWidth)
    }
}
