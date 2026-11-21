import CoreGraphics

/// Content heights the sheet sizes its detents from (in the content's own coordinates).
struct AnswerMetrics: Equatable {
    /// Bottom of the header (verdict + proof line): the collapsed detent (S7).
    var collapsed: CGFloat = 0
    /// Bottom of the shelf and branch rows: the medium detent (S5).
    var medium: CGFloat = 0
}
