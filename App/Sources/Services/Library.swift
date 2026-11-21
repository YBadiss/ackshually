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

/// M2 "library": the app opens straight into the last PDF (S1 game list is M3).
/// Imported PDFs are copied into Application Support so they survive relaunch.
enum Library {
    private static let lastKey = "lastRulebookPath"
    static let sampleFileName = "power-plant-rush.pdf"

    static var folder: URL {
        let u = URL.applicationSupportDirectory.appending(path: "Rulebooks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

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

    /// Stored relative to the folder when inside it (container paths change between installs).
    static func remember(_ url: URL) {
        let path = url.path.hasPrefix(folder.path) ? url.lastPathComponent : url.path
        UserDefaults.standard.set(path, forKey: lastKey)
    }

    static var last: URL? {
        guard let p = UserDefaults.standard.string(forKey: lastKey) else { return nil }
        let u = p.hasPrefix("/") ? URL(fileURLWithPath: p) : folder.appending(path: p)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
}
