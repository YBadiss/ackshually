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
    func cover(for url: URL, pixelWidth: Int) async -> UIImage? { nil }

    func importPDF(from picked: URL) throws -> URL {
        let dest = url(for: picked.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: picked, to: dest)
        return dest
    }

    func sampleRulebook() throws -> URL {
        let u = url(for: Library.sampleFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u) }
        return u
    }
}
