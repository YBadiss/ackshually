import Foundation
import AckshuallyCore

/// Evidence → where it lands on the PDF, and why.
enum HighlightPlacer {
    /// Note shown on the PDF when a quote didn't match: absence of a spotlight is never silent.
    static let notFoundNote = "Passage not found · showing the whole page"
    static let notLocatedNote = "Passage is on this page · couldn't mark it"

    /// Spec §4 order, M2 subset: quote match → box (if sane) → whole page, with a note saying which.
    /// Layout-tolerant matching and the repair call are later work.
    static func place(_ e: Evidence, matcher: QuoteMatcher) -> Highlight {
        let pageCount = max(matcher.pageCount, 1)
        let page = min(max(e.page, 1), pageCount)
        var quoteInfo: MatchInfo?
        if let q = e.quote, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            let outcome = matcher.match(quote: q, page: page)
            if let m = outcome.match {
                var info = MatchInfo(result: m.page == page ? .matched : .matchedOtherPage, detail: outcome.label,
                                     matchedPage: m.page, errorRate: m.errorRate, geometryScore: m.geometryScore, rects: m.rects.count)
                if m.rects.isEmpty {
                    info.result = .matchedNotLocated
                    info.detail = "matched, position not located"
                    return Highlight(page: m.page, kind: .wholePage, note: notLocatedNote, match: info)
                }
                return Highlight(page: m.page, kind: .words(m.rects), match: info)
            }
            if case .notMatched(let best, let reason) = outcome {
                quoteInfo = MatchInfo(result: .notMatched, detail: "not matched (\(reason))", errorRate: best)
            }
        }
        if let b = e.box {
            let check = QuoteMatcher.check(box: b)
            if check == .ok {
                return Highlight(page: page, kind: .box(b), match: MatchInfo(result: .figureBox, detail: "figure box", rects: 1))
            }
            let half = b.center.1 < 0.5 ? "upper half" : "lower half"
            return Highlight(page: page, kind: .wholePage, note: "See the diagram, \(half)",
                             match: quoteInfo ?? MatchInfo(result: .figureNoBox, detail: "box \(check.rawValue)"))
        }
        if let quoteInfo {
            return Highlight(page: page, kind: .wholePage, note: notFoundNote, match: quoteInfo)
        }
        return Highlight(page: page, kind: .wholePage, note: "See the figure on this page",
                         match: MatchInfo(result: .figureNoBox, detail: "no quote, no box"))
    }
}
