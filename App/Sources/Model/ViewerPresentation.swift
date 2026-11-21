import Foundation
import Observation

/// Which app-level dialogs are up (file importer, settings). A presenter that already shows the
/// answer sheet can't present again, so the dialogs attach to whichever view is frontmost:
/// the root, or the answer sheet while it is up (`answerSheetPresented`).
@MainActor
@Observable
final class ViewerPresentation {
    var importing = false
    var settings = false
    /// Set by the viewer layout while the compact answer sheet is presented.
    var answerSheetPresented = false
}
