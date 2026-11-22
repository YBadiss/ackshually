/// What the note over the PDF says about the spotlight (`HighlightOverlay`): sets its symbol.
enum HighlightNoteKind: Equatable {
    /// About a figure, or the passage is on the page but unmarked.
    case info
    /// Only part of the quote is spotlit ("Part of the passage highlighted").
    case partial
    /// The quote wasn't found or placed: whole page.
    case miss

    init(_ match: MatchInfo) {
        self = match.result == .partial ? .partial : match.isSpotlit ? .info : .miss
    }

    var symbol: String {
        switch self {
        case .info: "doc.text.magnifyingglass"
        case .partial: "highlighter"
        case .miss: "exclamationmark.magnifyingglass"
        }
    }
}
