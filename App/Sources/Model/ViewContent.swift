import Foundation
import AckshuallyCore

// Plain values the leaf views render. Built by `CardNavigator` or by preview fixtures; leaf views never
// reach into the models themselves.

/// Answer header (S4/S5): verdict + one proof line, fixed while stepping.
struct HeaderContent: Equatable {
    enum State: Equatable {
        /// S4: nothing but the (restated) question yet.
        case arriving
        case answered
        case failed(AnswerFailure)
    }
    var state: State
    /// Restated question when known, else what the user asked.
    var question: String
    var verdict: String?
    var confidence: Confidence?
    /// Cited pages ("p.3", or "Riverfolk p.4" with several books).
    var pages: [PageReference] = []
    /// Set while a branch is shown: "If no Battery".
    var condition: String?
    var isBusy = false
    var stopped = false
}

/// A web finding (S10, M4). Rendered by StepCard already so the card family is designed together.
struct WebFinding: Equatable {
    var site: String
    var date: String
    var role: String
    var quote: String
    /// "Designer disagrees" (strong) / "Community disagrees" (soft).
    var warning: String?
}

/// One card of the step carousel.
enum StepCardContent: Equatable {
    case step(number: Int, title: String, pages: [PageReference], text: String, figure: Bool)
    case loading(number: Int)
    case branch(condition: String, verdict: String)
    case web(number: Int, WebFinding)
}

struct CardItem: Identifiable, Equatable {
    var id: CardID
    var content: StepCardContent
}

/// The glass chrome over the PDF for the current evidence (`HighlightOverlay`): the quote pager and the
/// note about the spotlight.
struct HighlightChrome: Equatable {
    var evidenceIndex: Int
    var evidenceCount: Int
    var note: String?
    var noteKind: HighlightNoteKind
    /// Several books in play: where the passage is ("Riverfolk p.4"), shown in the pager.
    var location: String? = nil
}

/// A row of the full-answer step list (S9).
struct StepRow: Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var title: String
    var text: String
    var pages: [PageReference]
}

/// A branch row ("Without a Battery … Discard all 3 ›").
struct BranchRow: Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var condition: String
    var verdict: String
    var isActive: Bool
}

extension Step {
    /// Caption title: the contract's `title`, else "Step N" (older answers, citations mode).
    func displayTitle(number: Int) -> String { title ?? "Step \(number)" }

    var citedPages: [Int] { evidence.map(\.page).uniqued() }
}

extension StepCardContent {
    /// `reference` maps a page of the sent document to its book and page (one book: the page itself).
    static func step(_ s: Step, number: Int, reference: (Int) -> PageReference = PageReference.page) -> StepCardContent {
        .step(number: number, title: s.displayTitle(number: number), pages: s.citedPages.map(reference).uniqued(), text: s.text,
              figure: s.evidence.contains { $0.quote == nil })
    }
}

extension PageReference {
    /// A page of a one-book document ("p.3").
    static func page(_ p: Int) -> PageReference { PageReference(book: nil, page: p) }
}

extension [PageReference] {
    /// "p.3, p.4"; with several books, pages grouped by book in order:
    /// "Power Plant Rush p.3, p.4; Solar Expansion p.2".
    var label: String {
        var groups: [(book: String?, pages: [Int])] = []
        for r in self {
            if let last = groups.last, last.book == r.book { groups[groups.count - 1].pages.append(r.page) }
            else { groups.append((r.book, [r.page])) }
        }
        return groups.map { g in
            let pages = g.pages.map { "p.\($0)" }.joined(separator: ", ")
            return g.book.map { "\($0) \(pages)" } ?? pages
        }.joined(separator: "; ")
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
