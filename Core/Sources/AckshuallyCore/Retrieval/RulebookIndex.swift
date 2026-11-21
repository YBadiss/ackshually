import Foundation
import PDFKit

/// A parsed rulebook PDF: per-page text (PDFKit, same text layer as `QuoteMatcher`), its BM25 index,
/// and excerpt builders. Build once per document; it is immutable afterwards.
public final class RulebookIndex: @unchecked Sendable {
    public let document: PDFDocument
    public let pageTexts: [String]
    public let index: PageIndex
    private let lock = NSLock()

    public init(document: PDFDocument) {
        self.document = document
        pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        index = PageIndex(pageTexts: pageTexts)
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
