import Foundation
import PDFKit
import AckshuallyCore

/// An opened rulebook: one PDFDocument for the viewer, one QuoteMatcher (own PDFDocument, so
/// matching can run off the main thread), and the raw bytes sent to the provider.
final class LoadedRulebook: @unchecked Sendable {
    let url: URL
    let title: String
    let data: Data
    let pdf: PDFDocument
    let matcher: QuoteMatcher
    /// The generated "Power Plant Rush" fixture: the only document the scripted demo answer fits.
    var isSample: Bool { url.lastPathComponent == Library.sampleFileName }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let pdf = PDFDocument(data: data),
              let matcherDoc = PDFDocument(data: data) else { return nil }
        self.url = url
        self.data = data
        self.pdf = pdf
        self.matcher = QuoteMatcher(document: matcherDoc)
        let t = (pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespaces)
        self.title = Self.prettyTitle(from: url, pdfTitle: t)
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
/// they survive relaunch, and `library.json` next to them lists them (`LibraryIndex`, in Core).
enum Library {
    static let sampleFileName = "power-plant-rush.pdf"
    /// M2 remembered only the last rulebook; read once to migrate it into the index.
    private static let legacyLastKey = "lastRulebookPath"

    static var folder: URL {
        let u = URL.applicationSupportDirectory.appending(path: "Rulebooks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    static var indexURL: URL { folder.appending(path: "library.json") }

    static func url(for fileName: String) -> URL { folder.appending(path: fileName) }

    /// Copies a file picked with the importer (security-scoped) into the app's folder.
    static func importPDF(from picked: URL) throws -> URL {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let dest = folder.appending(path: picked.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: picked, to: dest)
        return dest
    }

    static func sampleRulebook() throws -> URL {
        let u = folder.appending(path: sampleFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u) }
        return u
    }

    static func deleteFile(named fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    // MARK: Index

    /// The saved index, minus games whose file is gone. On the first launch after M2 (no index
    /// yet, or an unreadable one) it is rebuilt from the PDFs already in the folder.
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

    /// Empties My Games: the index and every imported copy (`-emptyLibrary YES`).
    static func reset() -> LibraryIndex {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for f in files { try? FileManager.default.removeItem(at: f) }
        let empty = LibraryIndex()
        save(empty)
        return empty
    }

    /// Title shown in My Games and the viewer bar (same rule as `LoadedRulebook.title`).
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
