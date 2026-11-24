import Foundation

/// A book's place in a game (S13): core books are always in play, add-ons (expansions, FAQs, errata) are
/// ticked per game night.
public enum BookRole: String, Codable, Sendable, CaseIterable {
    case core
    case addOn = "add_on"
}

/// One book of the document sent for a game: where its pages sit in that document.
public struct BookPart: Codable, Sendable, Equatable {
    public var title: String
    public var role: BookRole
    /// First page of this book in the sent document (1-based).
    public var firstPage: Int
    public var pageCount: Int

    public init(title: String, role: BookRole, firstPage: Int, pageCount: Int) {
        self.title = title
        self.role = role
        self.firstPage = firstPage
        self.pageCount = pageCount
    }

    public var lastPage: Int { firstPage + pageCount - 1 }
    public var pages: ClosedRange<Int> { firstPage...max(firstPage, lastPage) }
}

/// A page of the sent document, back in its own book: "Riverfolk p.4". `book` is nil when the document is
/// a single book (the label is then just "p.4", as before several books existed).
public struct PageReference: Hashable, Sendable, Codable {
    public var book: String?
    /// The page in that book (1-based, physical page of the book's own PDF).
    public var page: Int

    public init(book: String?, page: Int) {
        self.book = book
        self.page = page
    }

    /// "Riverfolk p.4" / "p.4".
    public var label: String { book.map { "\($0) p.\(page)" } ?? "p.\(page)" }
    /// VoiceOver: "Riverfolk, page 4" / "page 4".
    public var spokenLabel: String { book.map { "\($0), page \(page)" } ?? "page \(page)" }
}

/// The table of contents and page map of what a game sends (S13): the books in play one after another, plus
/// the add-ons that are not. The answer contract is unchanged: evidence pages are pages of the sent document,
/// and `reference(for:)` maps them back to a book and its own page.
public struct RulebookContents: Codable, Sendable, Equatable {
    public var gameTitle: String
    /// Books in play, in document order.
    public var parts: [BookPart]
    /// Titles of the game's add-ons that are not ticked.
    public var notInPlay: [String]

    public init(gameTitle: String, parts: [BookPart], notInPlay: [String] = []) {
        self.gameTitle = gameTitle
        self.parts = parts
        self.notInPlay = notInPlay
    }

    /// Books in play one after another, from their page counts.
    public init(gameTitle: String, books: [(title: String, role: BookRole, pageCount: Int)], notInPlay: [String] = []) {
        var next = 1
        var parts: [BookPart] = []
        for b in books {
            parts.append(BookPart(title: b.title, role: b.role, firstPage: next, pageCount: b.pageCount))
            next += b.pageCount
        }
        self.init(gameTitle: gameTitle, parts: parts, notInPlay: notInPlay)
    }

    public var pageCount: Int { parts.last?.lastPage ?? 0 }

    /// More than one book in the document: page labels name the book.
    public var isJoined: Bool { parts.count > 1 }

    /// Index of the book holding `page` of the sent document.
    public func partIndex(of page: Int) -> Int? {
        parts.firstIndex { $0.pages.contains(page) }
    }

    /// `page` of the sent document → its book and that book's own page. Pages outside every book (a model
    /// citing a page that doesn't exist) keep their number and no book.
    public func reference(for page: Int) -> PageReference {
        guard let i = partIndex(of: page) else { return PageReference(book: nil, page: page) }
        let p = parts[i]
        return PageReference(book: isJoined ? p.title : nil, page: page - p.firstPage + 1)
    }

    /// A book's own page → the page of the sent document (bench expectations, the book switcher).
    public func documentPage(book title: String, page: Int) -> Int? {
        guard let p = parts.first(where: { $0.title == title }), page >= 1, page <= p.pageCount else { return nil }
        return p.firstPage + page - 1
    }

    /// Something for the prompt to say: several books, or add-ons left out.
    public var needsPromptNote: Bool { isJoined || !notInPlay.isEmpty }

    /// The note sent before the document: table of contents (book, kind, page range), the order of authority,
    /// and what is not in play. Stable for a given set of books, so it sits in the cached prefix.
    public var promptNote: String {
        var s = ""
        if isJoined {
            s += "The attached PDF holds the rulebooks for \"\(gameTitle)\" in play tonight, joined into one file, one book after another:\n"
            for p in parts {
                let range = p.pageCount > 1 ? "pages \(p.firstPage)–\(p.lastPage)" : "page \(p.firstPage)"
                s += "- \(range): \"\(p.title)\" (\(p.role == .core ? "core" : "add-on"))\n"
            }
            s += """
            Page numbers in evidence are pages of this file (the ranges above), never the page numbers printed \
            on the pages.
            When books disagree, follow the more authoritative one: errata and FAQs over a rules reference, and a \
            rules reference over a learning guide or walkthrough. Judge what kind of book each one is from its \
            title and content. Cite the most authoritative passage; a learning guide may be cited alongside it.

            """
        } else if let p = parts.first {
            s += "The attached PDF is \"\(p.title)\", the rulebook in play tonight for \"\(gameTitle)\".\n"
        }
        if !notInPlay.isEmpty {
            let names = notInPlay.map { "\"\($0)\"" }.joined(separator: ", ")
            s += """
            Not in play tonight (add-ons the players did not pick): \(names). Content that only they add (their \
            factions, cards, maps, pieces and rules) is not part of this game, even where the books above describe \
            it: a rules reference often covers its expansions too. If the question is about such content, still \
            answer from the books above if they cover it, and add the assumption that it is in play (it is not \
            ticked tonight); if they don't cover it, set confidence to "not_covered" and say which add-on it \
            belongs to.

            """
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
