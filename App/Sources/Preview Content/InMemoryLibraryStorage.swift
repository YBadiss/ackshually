import UIKit
import Synchronization
import AckshuallyCore

/// A library in a throwaway folder; the index lives only in memory.
final class InMemoryLibraryStorage: LibraryStorage {
    private let index: Mutex<LibraryIndex>
    let folder: URL

    init(index: LibraryIndex = LibraryIndex(),
         folder: URL = FileManager.default.temporaryDirectory.appending(path: "preview-library", directoryHint: .isDirectory)) {
        self.index = Mutex(index)
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func loadIndex() -> LibraryIndex { index.withLock { $0 } }
    func save(_ i: LibraryIndex) { index.withLock { $0 = i } }
    func reset() -> LibraryIndex { index.withLock { $0 = LibraryIndex(); return $0 } }
    func url(for fileName: String) -> URL { folder.appending(path: fileName) }
    func title(of url: URL) -> String { LoadedRulebook.prettyTitle(from: url, pdfTitle: nil) }
    func delete(fileName: String) async { try? FileManager.default.removeItem(at: url(for: fileName)) }
    func moveToPending(fileName: String) { Library.moveToPending(fileName, in: folder) }
    func restoreFromPending(fileNames: [String]) -> Bool { Library.restoreFromPending(fileNames, in: folder) }
    func purgePending() async { Library.purgePending(in: folder) }
    func cover(for url: URL, pixelWidth: Int) async -> UIImage? { nil }

    func importPDF(from picked: URL) throws -> URL { try Library.importPDF(from: picked, into: folder) }

    func load(_ game: LibraryEntry) -> LoadedRulebook? {
        let joined = folder.appending(path: "Joined", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: joined, withIntermediateDirectories: true)
        return Library.load(game, url: url(for:), joined: joined)
    }

    /// The made-up Solar Expansion (S13 previews and tests), written into the folder on first use.
    func sampleExpansion() throws -> URL {
        let u = url(for: Library.sampleExpansionFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u, pages: FixtureRulebook.expansionPages) }
        return u
    }

    func sampleRulebook() throws -> URL {
        let u = url(for: Library.sampleFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u) }
        return u
    }
}
