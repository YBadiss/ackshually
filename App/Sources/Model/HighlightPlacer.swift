import Foundation
import AckshuallyCore

/// Evidence → where it lands on the PDF.
enum HighlightPlacer {
    /// Spec §4 order, M2 subset: quote match → box (if sane) → whole page. Layout-tolerant
    /// matching and the repair call are out of M2 scope.
    static func place(_ e: Evidence, matcher: QuoteMatcher) -> Highlight {
        let pageCount = max(matcher.pageCount, 1)
        let page = min(max(e.page, 1), pageCount)
        if let q = e.quote, let m = matcher.match(quote: q, page: page).match, !m.rects.isEmpty {
            return Highlight(page: m.page, kind: .words(m.rects))
        }
        if let b = e.box {
            if QuoteMatcher.check(box: b) == .ok { return Highlight(page: page, kind: .box(b)) }
            let half = b.center.1 < 0.5 ? "upper half" : "lower half"
            return Highlight(page: page, kind: .wholePage, note: "See the diagram, \(half)")
        }
        if e.quote == nil { return Highlight(page: page, kind: .wholePage, note: "See the figure on this page") }
        return Highlight(page: page, kind: .wholePage)
    }
}
