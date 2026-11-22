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
    /// the answer streams once sized, and otherwise only growing, so the sheet never shrinks
    /// under the reader (it used to re-measure on every streamed event and jump).
    func next(measured: AnswerMetrics, streaming: Bool) -> AnswerMetrics {
        if streaming, isSized { return self }
        return AnswerMetrics(collapsed: max(collapsed, measured.collapsed), medium: max(medium, measured.medium))
    }
}
