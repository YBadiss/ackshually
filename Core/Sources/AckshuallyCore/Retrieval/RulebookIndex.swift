import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformFont = NSFont
#endif

/// A parsed rulebook PDF: per-page text (PDFKit, same text layer as `QuoteMatcher`), its BM25 index,
/// and excerpt builders. Build once per document; it is immutable afterwards.
public final class RulebookIndex: @unchecked Sendable {
    public let document: PDFDocument
    public let pageTexts: [String]
    /// Text set in a larger font than the body (section headings), per page.
    public let headings: [String]
    public let index: PageIndex
    /// Quote locator on the same document (corrects mis-numbered evidence pages on excerpts).
    public let matcher: QuoteMatcher
    private let lock = NSLock()

    public init(document: PDFDocument) {
        self.document = document
        pageTexts = (0..<document.pageCount).map { Self.pageText(document, at: $0) }
        headings = Self.headings(document)
        index = PageIndex(pageTexts: pageTexts, headings: headings)
        matcher = QuoteMatcher(document: document)
    }

    /// One page's text layer (PDFKit; the same text `QuoteMatcher` reads). "" for a page without text.
    public static func pageText(_ document: PDFDocument, at index: Int) -> String {
        document.page(at: index)?.string ?? ""
    }

    /// Original page for one piece of excerpt evidence: the page the model named (mapped from an
    /// excerpt position if needed), unless its quote is not there but is on another selected page.
    public func resolvePage(_ e: Evidence, in selection: PageSelection, excerptPositions: Bool = false) -> Int {
        let named = excerptPositions ? (selection.originalPage(excerptPage: e.page) ?? e.page) : selection.resolveModelPage(e.page)
        guard !selection.isFullDocument, let q = e.quote, !q.isEmpty else { return named }
        return matcher.locate(quote: q, candidates: [named] + selection.pages) ?? named
    }

    /// Runs whose font is ≥ 1.25× the body size (most common size by characters). Cheap: one
    /// attributed-string pass per page. Rulebooks without real headings (all one size) give "".
    static func headings(_ d: PDFDocument) -> [String] {
        let pages = (0..<d.pageCount).map { d.page(at: $0)?.attributedString }
        var sizes: [Int: Int] = [:]
        for a in pages.compactMap({ $0 }) {
            a.enumerateAttribute(.font, in: NSRange(location: 0, length: a.length)) { v, r, _ in
                if let f = v as? PlatformFont { sizes[Int(f.pointSize.rounded()), default: 0] += r.length }
            }
        }
        guard let body = sizes.max(by: { $0.value < $1.value })?.key, body > 0 else { return pages.map { _ in "" } }
        return pages.map { a in
            guard let a else { return "" }
            var out: [String] = []
            let ns = a.string as NSString
            a.enumerateAttribute(.font, in: NSRange(location: 0, length: a.length)) { v, r, _ in
                guard let f = v as? PlatformFont, f.pointSize >= Double(body) * 1.25, f.pointSize <= Double(body) * 4 else { return }
                out.append(ns.substring(with: r))
            }
            return out.joined(separator: " ")
        }
    }

    public convenience init?(data: Data) {
        guard let d = PDFDocument(data: data) else { return nil }
        self.init(document: d)
    }

    public convenience init?(url: URL) {
        guard let d = PDFDocument(url: url) else { return nil }
        self.init(document: d)
    }

    public var pageCount: Int { document.pageCount }

    public func select(question: String, history: [Turn] = [], options: PageSelectionOptions) -> PageSelection {
        let pinned = history.flatMap { $0.answer?.steps.flatMap { $0.evidence.map(\.page) } ?? [] }
        return index.select(question: question, history: history.map(\.question), pinned: Array(Set(pinned)).sorted(),
                            options: options)
    }

    /// Exactly these pages (manual selection).
    public func selection(pages: [Int]) -> PageSelection {
        let p = Array(Set(pages.filter { $0 >= 1 && $0 <= pageCount })).sorted()
        if p.isEmpty || p.count == pageCount { return .full(pageCount: pageCount, reason: p.isEmpty ? "no valid pages" : nil) }
        return PageSelection(pages: p, pageCount: pageCount)
    }

    /// A new PDF holding only `selection.pages`, in order (page images and text layer kept).
    public func excerptPDF(_ selection: PageSelection) -> Data? {
        lock.lock(); defer { lock.unlock() }  // PDFDocument is not thread-safe
        let out = PDFDocument()
        for (i, p) in selection.pages.enumerated() {
            guard let page = document.page(at: p - 1)?.copy() as? PDFPage else { return nil }
            out.insert(page, at: i)
        }
        return out.dataRepresentation()
    }

    /// Text-only excerpt: each page's text layer under a "rulebook page N" header.
    public func excerptText(_ selection: PageSelection, title: String) -> String {
        var s = "Rulebook excerpt: \(title)\n"
        for p in selection.pages {
            s += "\n=== Rulebook page \(p) ===\n" + pageTexts[p - 1].trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }
        return s
    }
}
