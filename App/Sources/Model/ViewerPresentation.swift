import Foundation
import Observation

/// Which viewer dialogs are up (Settings when a credential is needed or rejected, Answer Details, Playing with). Owned by
/// the game's `ViewerModel`. A presenter that already shows the
/// answer sheet can't present again, so the dialogs attach to whichever view is frontmost:
/// the root, or the answer sheet while it is up (`answerSheetPresented`).
@MainActor
@Observable
final class ViewerPresentation {
    var settings = false
    /// ⋯ → Answer Details (evidence match status, Copy JSON).
    var answerDetails = false
    /// The title button → "Playing with" (S13): the books in play, changed from the next question.
    var playingWith = false
    /// Set by the viewer layout while the compact answer sheet is presented.
    var answerSheetPresented = false
}
