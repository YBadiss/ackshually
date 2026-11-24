import Foundation
import PDFKit
import CryptoKit
import AckshuallyCore

/// The document a game's viewer shows and asks about: its books in play joined into one PDF (one book: that
/// PDF), with one PDFDocument for the viewer, one QuoteMatcher (own PDFDocument, so matching can run off the
/// main thread), the bytes sent to the provider and the page map back to (book, page). Built off the main
/// thread (`Library.load`); immutable afterwards.
final class LoadedRulebook: @unchecked Sendable {
    /// What the game shows as its title (the viewer bar, the prompt's game name).
    let title: String
    let data: Data
    let pdf: PDFDocument
    let matcher: QuoteMatcher
    /// Books in the document, their page ranges, and the add-ons left out.
    let contents: RulebookContents
    /// The rulebook files in play, in order: two documents with the same files are the same set.
    let fileNames: [String]
    /// Page index for documents too large to send whole (page selection needs it on every question);
    /// nil otherwise (the provider never parses the PDF then).
    let index: RulebookIndex?
    /// What this document was built from (`Library.signature`): a game whose books, ticks or names changed
    /// since needs a new one.
    let signature: String
    /// The generated "Power Plant Rush" fixture alone: the only document the scripted demo answer fits.
    var isSample: Bool { fileNames == [Library.sampleFileName] }

    init?(title: String, data: Data, contents: RulebookContents, fileNames: [String], signature: String = "") {
        guard let pdf = PDFDocument(data: data), let matcherDoc = PDFDocument(data: data) else { return nil }
        self.signature = signature
        self.title = title
        self.data = data
        self.pdf = pdf
        self.matcher = QuoteMatcher(document: matcherDoc)
        self.contents = contents
        self.fileNames = fileNames
        // Its own PDFDocument: PDFKit documents aren't thread-safe, and matching and page selection run apart.
        index = data.count > ClaudeProvider.maxDocumentBytes ? RulebookIndex(data: data) : nil
    }

    /// One PDF on its own (launch arguments, fixtures): titled from the file.
    convenience init?(url: URL) {
        guard let data = try? Data(contentsOf: url), let doc = PDFDocument(data: data) else { return nil }
        let t = (doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespaces)
        let title = Self.prettyTitle(from: url, pdfTitle: t)
        self.init(title: title, data: data, contents: RulebookContents(gameTitle: title, books: [(title, .core, doc.pageCount)]),
                  fileNames: [url.lastPathComponent], signature: url.lastPathComponent)
    }

    static func prettyTitle(from url: URL, pdfTitle: String?) -> String {
        let base = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        let name = base.prefix(1).uppercased() + base.dropFirst()
        if let t = pdfTitle, !t.isEmpty, t.count < 40, !t.lowercased().hasPrefix("microsoft") { return t }
        return name
    }
}

/// Files behind My Games (S1): imported PDFs are copied into Application Support/Rulebooks so
/// they survive relaunch, and `library.json` next to them lists the games and their books (`LibraryIndex`,
/// in Core). Joined documents for games with several books in play are cached in Caches/Joined.
enum Library {
    static let sampleFileName = "power-plant-rush.pdf"
    /// M2 remembered only the last rulebook; read once to migrate it into the index.
    private static let legacyLastKey = "lastRulebookPath"

    /// Created once, on first use (it used to be re-created on every access).
    static let folder: URL = {
        let u = URL.applicationSupportDirectory.appending(path: "Rulebooks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static let joinedFolder: URL = {
        let u = URL.cachesDirectory.appending(path: "Joined", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static var indexURL: URL { folder.appending(path: "library.json") }

    static func url(for fileName: String) -> URL { folder.appending(path: fileName) }

    /// Copies a file picked with the importer (security-scoped) into `folder`. A name already taken (by this
    /// game or another one) gets a number ("rules 2.pdf"): a file belongs to one game.
    static func importPDF(from picked: URL, into folder: URL = folder) throws -> URL {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let dest = uniqueURL(for: picked.lastPathComponent, in: folder)
        try FileManager.default.copyItem(at: picked, to: dest)
        return dest
    }

    static func uniqueURL(for name: String, in folder: URL) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appending(path: name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }

    static func sampleRulebook() throws -> URL {
        let u = folder.appending(path: sampleFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u) }
        return u
    }

    /// The sample's made-up Solar Expansion (`-seedSampleSet YES`).
    static func sampleExpansion() throws -> URL {
        let u = folder.appending(path: sampleExpansionFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u, pages: FixtureRulebook.expansionPages) }
        return u
    }

    static let sampleExpansionFileName = "solar-expansion.pdf"

    static func deleteFile(named fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    // MARK: Opening a game

    /// The document for `game`'s books in play. One book: its PDF as is. Several: joined once and kept in
    /// `joined` (the joined bytes differ on every join, and the prompt cache only hits on identical bytes),
    /// keyed by the files and their modification dates. Slow the first time (~2–3 s): call off the main thread.
    static func load(_ game: LibraryEntry, url: (String) -> URL, joined: URL) -> LoadedRulebook? {
        let books = game.booksInPlay
        guard !books.isEmpty else { return nil }
        let names = books.map(\.fileName)
        let notInPlay = game.notInPlay.map(\.title)
        var sources: [RulebookSource] = []
        for b in books {
            guard let d = try? Data(contentsOf: url(b.fileName)) else { return nil }
            sources.append(RulebookSource(title: b.title, role: b.role, pdf: d))
        }
        guard sources.count > 1 else {
            guard let doc = PDFDocument(data: sources[0].pdf) else { return nil }
            let contents = RulebookContents(gameTitle: game.title, books: [(books[0].title, .core, doc.pageCount)], notInPlay: notInPlay)
            return LoadedRulebook(title: game.title, data: sources[0].pdf, contents: contents, fileNames: names,
                                  signature: signature(of: game))
        }
        let cached = joined.appending(path: joinedKey(books, url: url) + ".pdf")
        if let data = try? Data(contentsOf: cached), let doc = PDFDocument(data: data) {
            let counts = sources.compactMap { PDFDocument(data: $0.pdf)?.pageCount }
            if counts.count == sources.count, counts.reduce(0, +) == doc.pageCount {
                let contents = RulebookContents(gameTitle: game.title,
                                                books: zip(books, counts).map { ($0.title, $0.role, $1) }, notInPlay: notInPlay)
                return LoadedRulebook(title: game.title, data: data, contents: contents, fileNames: names,
                                      signature: signature(of: game))
            }
        }
        guard let j = RulebookJoiner.join(sources, gameTitle: game.title, notInPlay: notInPlay) else { return nil }
        try? j.pdf.write(to: cached, options: .atomic)
        pruneJoined(in: joined, keep: 8)
        return LoadedRulebook(title: game.title, data: j.pdf, contents: j.contents, fileNames: names,
                              signature: signature(of: game))
    }

    /// Everything a loaded document depends on: the game's title, its books in play (file, title, role) in
    /// order, and the titles of the add-ons left out.
    static func signature(of game: LibraryEntry) -> String {
        ([game.title] + game.booksInPlay.map { "\($0.fileName)|\($0.title)|\($0.role.rawValue)" } + ["not in play"]
            + game.notInPlay.map(\.title)).joined(separator: "\n")
    }

    /// Same files (and versions of them) in the same order → same key. Titles and roles aren't part of it:
    /// they only change the contents, which are rebuilt on every load.
    static func joinedKey(_ books: [LibraryBook], url: (String) -> URL) -> String {
        let parts = books.map { b -> String in
            let v = (try? url(b.fileName).resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]))
            return "\(b.fileName)|\(v?.fileSize ?? 0)|\(v?.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        }
        let digest = SHA256.hash(data: Data(parts.joined(separator: "\n").utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Keeps the `keep` most recently written joined documents.
    private static func pruneJoined(in folder: URL, keep: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let dated = files.map { f in (f, (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }
        for (f, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(keep) { try? FileManager.default.removeItem(at: f) }
    }

    // MARK: Index

    /// The saved index (games from before several books load as one core book each), minus books whose
    /// file is gone. On the first launch after M2 (no index yet, or an unreadable one) it is rebuilt from
    /// the PDFs already in the folder.
    static func loadIndex() -> LibraryIndex {
        var index: LibraryIndex
        do {
            index = try LibraryIndex.load(from: indexURL) ?? migratedIndex()
        } catch {
            index = migratedIndex()
        }
        index.prune { FileManager.default.fileExists(atPath: url(for: $0).path) }
        save(index)
        return index
    }

    static func save(_ index: LibraryIndex) {
        try? index.save(to: indexURL)
    }

    /// Empties My Games: the index, every imported copy and every joined document (`-emptyLibrary YES`).
    static func reset() -> LibraryIndex {
        for dir in [folder, joinedFolder] {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
        let empty = LibraryIndex()
        save(empty)
        return empty
    }

    /// Title shown in My Games and the viewer bar (same rule as `LoadedRulebook.prettyTitle`).
    static func title(of url: URL) -> String {
        let t = (PDFDocument(url: url)?.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespaces)
        return LoadedRulebook.prettyTitle(from: url, pdfTitle: t)
    }

    /// Every PDF already imported becomes a game; the M2 "last rulebook" is the most recent.
    /// The sample only counts if it was the last one opened (launch arguments also write it here).
    private static func migratedIndex() -> LibraryIndex {
        let d = UserDefaults.standard
        let last = d.string(forKey: legacyLastKey).map { URL(fileURLWithPath: $0).lastPathComponent }
        d.removeObject(forKey: legacyLastKey)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var index = LibraryIndex()
        for f in files where f.pathExtension.lowercased() == "pdf" {
            let name = f.lastPathComponent
            if name == sampleFileName, name != last { continue }
            let modified = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
            index.record(fileName: name, title: title(of: f), at: name == last ? .now : modified)
        }
        return index
    }
}
