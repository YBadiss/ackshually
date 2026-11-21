import Foundation

/// Where the answer is shown; decides which parts are visible.
enum AnswerPlacement: Equatable {
    /// System sheet on compact screens, at a detent.
    case sheet(SheetDetent)
    /// Inspector column on wide screens: everything, no detents.
    case inspector

    var isExpanded: Bool { self == .inspector || self == .sheet(.expanded) }
    /// Collapsed sheet (S7): only the verdict and proof line are shown.
    var isCollapsed: Bool { self == .sheet(.collapsed) }
}
