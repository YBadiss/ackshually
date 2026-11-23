import CoreGraphics

/// Content heights the sheet sizes its detents from (in the content's own coordinates).
struct AnswerMetrics: Equatable {
    /// Bottom of the header (verdict + proof line): the collapsed detent (S7).
    var collapsed: CGFloat = 0
    /// Bottom of the shelf, follow-up row and branch rows: the medium detent (S5).
    var medium: CGFloat = 0

    /// Both detents measured, and medium distinct from collapsed.
    var isSized: Bool { collapsed > 0 && medium > collapsed }

    /// The heights the sheet should use next, given the latest `measured` content: frozen while
    /// the answer streams once sized (it used to re-measure on every streamed event and jump), and
    /// fitted to the content otherwise, so a finished answer settles once to its real size.
    func next(measured: AnswerMetrics, streaming: Bool) -> AnswerMetrics {
        streaming && isSized ? self : measured
    }
}
