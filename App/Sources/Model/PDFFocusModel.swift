import Foundation
import Observation

/// What the PDF shows: the highlight it is focused on (a new token re-applies it), evidence zoom or the whole
/// page (S8 double-tap), and whether the reader moved the page themselves (double-tap brings it back).
@MainActor
@Observable
final class PDFFocusModel {
    private(set) var zoom: ZoomMode = .evidence
    private(set) var focus: PDFFocus?
    /// Set by the PDF view when the user pinches/pans: stop re-centering until a double-tap or a new card.
    var userMovedPDF = false
    @ObservationIgnored private var token = 0

    /// Re-centre on a sheet / container change only while following the evidence.
    var followsEvidence: Bool { !userMovedPDF && focus != nil }

    func show(_ h: Highlight) {
        token += 1
        focus = PDFFocus(token: token, highlight: h, zoom: zoom)
    }

    /// Back to the evidence zoom, following it again (new card, next quote).
    func followEvidence() {
        zoom = .evidence
        userMovedPDF = false
    }

    /// S8 double-tap: evidence zoom ↔ full page (a moved page goes back to the evidence first).
    func toggleZoom() {
        zoom = (zoom == .evidence && !userMovedPDF) ? .page : .evidence
        userMovedPDF = false
    }

    /// The answer closed: nothing is focused (the PDF goes back to the whole page).
    func clear() {
        focus = nil
        userMovedPDF = false
    }
}
