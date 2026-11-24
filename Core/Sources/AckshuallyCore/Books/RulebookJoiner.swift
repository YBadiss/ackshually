import Foundation
import PDFKit

/// One book to send: its title, role and PDF bytes.
public struct RulebookSource: Sendable {
    public var title: String
    public var role: BookRole
    public var pdf: Data

    public init(title: String, role: BookRole, pdf: Data) {
        self.title = title
        self.role = role
        self.pdf = pdf
    }
}

/// The document a game sends: the books in play joined into one PDF, and its contents (page map, table of
/// contents, what is not in play).
public struct JoinedRulebook: Sendable {
    public let pdf: Data
    public let contents: RulebookContents

    public init(pdf: Data, contents: RulebookContents) {
        self.pdf = pdf
        self.contents = contents
    }
}

/// Joins a game's books in play into one PDF (S13), so Core keeps its single-document path: page selection,
/// the 1-hour prompt cache and page remapping all work on the joined file, and `RulebookContents` maps its
/// pages back to (book, page).
///
/// Joining rewrites the PDF (~2–3 s for a few large books) and the bytes differ between runs (PDFKit writes a
/// new document ID), so callers keep the result (the app caches it on disk): the prompt cache only hits on
/// identical bytes.
public enum RulebookJoiner {
    /// nil when a book isn't a readable PDF or there are none. A single book is passed through unchanged
    /// (same bytes as before several books existed: its cache entry stays warm).
    public static func join(_ books: [RulebookSource], gameTitle: String, notInPlay: [String] = []) -> JoinedRulebook? {
        guard !books.isEmpty else { return nil }
        var docs: [PDFDocument] = []
        for b in books {
            guard let d = PDFDocument(data: b.pdf), d.pageCount > 0 else { return nil }
            docs.append(d)
        }
        let contents = RulebookContents(gameTitle: gameTitle,
                                        books: zip(books, docs).map { ($0.title, $0.role, $1.pageCount) },
                                        notInPlay: notInPlay)
        if books.count == 1 { return JoinedRulebook(pdf: books[0].pdf, contents: contents) }
        let out = PDFDocument()
        for d in docs {
            for i in 0..<d.pageCount {
                guard let page = d.page(at: i) else { return nil }
                out.insert(page, at: out.pageCount)
            }
        }
        guard let data = out.dataRepresentation() else { return nil }
        return JoinedRulebook(pdf: data, contents: contents)
    }
}
