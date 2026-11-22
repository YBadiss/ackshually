import Foundation

/// How one piece of evidence was placed on the PDF: shown in Answer details, copied with the
/// raw answer JSON and logged in debug builds, so a missing highlight can be explained.
struct MatchInfo: Equatable, Sendable, Encodable {
    enum Result: String, Equatable, Sendable, Encodable {
        /// Quote found on the cited page and located: spotlit.
        case matched
        /// Quote found on another page (shown there).
        case matchedOtherPage = "matched_other_page"
        /// Quote found, but its position on the page couldn't be trusted: whole page.
        case matchedNotLocated = "matched_not_located"
        /// Quote not found in the text: whole page.
        case notMatched = "not_matched"
        /// Figure box drawn.
        case figureBox = "figure_box"
        /// Figure without a usable box: whole page.
        case figureNoBox = "figure_no_box"
    }

    var result: Result
    /// Human-readable: "matched", "not matched (best error 44%)", "box out of page"…
    var detail: String
    var matchedPage: Int?
    var errorRate: Double?
    var geometryScore: Double?
    var rects = 0

    /// True when something is spotlit on the page.
    var isSpotlit: Bool { [.matched, .matchedOtherPage, .figureBox].contains(result) }
}
