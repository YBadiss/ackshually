import Foundation
import Observation
import AckshuallyCore

/// One game's viewer session (created per rulebook by `LibraryModel`, kept when you go back). A thin
/// coordinator over its parts, which views use directly:
/// - `session` (`AnswerSession`): asking, streaming, stop/retry, follow-ups, failures, feedback;
/// - `navigator` (`CardNavigator`): cards, branches, the quote pager, "More";
/// - `highlights` (`HighlightStore`): quote → highlight, resolved once off the main thread;
/// - `pdfFocus` (`PDFFocusModel`): what the PDF zooms to and whether the reader moved it;
/// - `presentation` (`ViewerPresentation`): Settings / Answer Details.
/// It wires their changes together (a new card moves the PDF, a resolved highlight focuses it, a missing
/// credential opens Settings) and owns the one rule for when the answer is on screen (`sheetVisible`).
@MainActor
@Observable
final class ViewerModel {
    let rulebook: LoadedRulebook
    let session: AnswerSession
    let navigator: CardNavigator
    let highlights: HighlightStore
    let pdfFocus = PDFFocusModel()
    let presentation = ViewerPresentation()
    let providers: any AnswerProviderFactory

    var detent: SheetDetent = .medium
    /// The reader closed the answer (header ✕, Hide Answer). The only stored input of `sheetVisible`.
    private(set) var sheetClosed = false

    init(rulebook: LoadedRulebook, providers: any AnswerProviderFactory, place: HighlightStore.Placer? = nil) {
        self.rulebook = rulebook
        self.providers = providers
        session = AnswerSession(rulebook: rulebook, providers: providers)
        navigator = CardNavigator(session: session)
        highlights = place.map(HighlightStore.init(place:)) ?? HighlightStore(matcher: rulebook.matcher)
        session.onChange = { [unowned self] in self.sessionChanged($0) }
        navigator.onCardChange = { [unowned self] in
            self.pdfFocus.followEvidence()
            self.refocus()
        }
        highlights.onResolved = { [unowned self] e, h in
            self.logMatch(e, h)
            if let cur = self.navigator.currentEvidence, HighlightStore.key(cur) == HighlightStore.key(e) { self.refocus() }
        }
    }

    // MARK: Sheet

    /// When the answer (sheet, inspector or column) is on screen. Spec S4: not while waiting for the first
    /// token (the ask bar shows progress), always while streaming (it never hides or jumps under the reader:
    /// closing it stops the answer), and once done or failed until the reader closes it.
    var sheetVisible: Bool {
        guard session.answer != nil else { return false }
        switch session.phase {
        case .waiting: return false
        case .streaming: return true
        case .done, .failed: return !sheetClosed
        }
    }

    func dismissSheet() {
        if session.isBusy { session.stop() }
        sheetClosed = true
        pdfFocus.clear()
    }

    func showSheet() {
        guard session.answer != nil else { return }
        sheetClosed = false
        refocus()
    }

    /// "More" on a truncated card: the expanded answer, scrolled to that step's full text.
    func showMore(_ card: CardID) {
        navigator.showMore(card)
        detent = .expanded
    }

    /// The ⋯ menu's "Demo answers: no access token set".
    var showsDemoNote: Bool { session.isDemo || providers.claudeRoute == nil }

    private func sessionChanged(_ change: AnswerSession.Change) {
        switch change {
        case .started:
            navigator.reset()
            pdfFocus.followEvidence()
            sheetClosed = false
            detent = .medium
        case .needsCredential:
            presentation.settings = true
        case .evidence(let evidence):
            evidence.forEach(highlights.resolve)
        case .step(let i):
            navigator.rebuild(newStep: i)
        case .updated:
            navigator.rebuild()
        case .completed:
            navigator.rebuild()
            logAnswer()
        case .stopped:
            if session.answer != nil { navigator.rebuild() }
        case .failed:
            break
        }
    }

    // MARK: PDF

    var currentHighlight: Highlight? { navigator.currentEvidence.flatMap { highlights[$0] } }

    /// The overlay over the PDF: a note when the spotlight isn't the exact quote, a pager when the step
    /// cites several passages; nil when there is nothing to say (one passage, spotlit exactly). Never an
    /// empty overlay: an empty glass container over the PDF made UIKit re-lay out the screen in a loop
    /// ("Observation tracking feedback loop detected", ~45 per second).
    var highlightChrome: HighlightChrome? {
        guard sheetVisible, pdfFocus.focus != nil else { return nil }
        let h = currentHighlight
        let note = h?.note ?? (h?.kind == .wholePage ? HighlightPlacer.notFoundNote : nil)
        let count = navigator.currentStep?.evidence.count ?? 0
        guard note != nil || count > 1 else { return nil }
        return HighlightChrome(evidenceIndex: navigator.evidenceIndex, evidenceCount: count, note: note,
                               noteKind: h.map { HighlightNoteKind($0.match) } ?? .info)
    }

    func nextEvidence() {
        guard navigator.nextEvidence() else { return }
        pdfFocus.followEvidence()
        refocus()
    }

    func backToStep() {
        pdfFocus.followEvidence()
        refocus()
    }

    /// S8 double-tap: evidence zoom ↔ full page.
    func toggleZoom() {
        guard currentHighlight != nil else { return }
        pdfFocus.toggleZoom()
        refocus()
    }

    /// Re-center after the visible area changes (sheet detent), unless the user is inspecting.
    func visibleAreaChanged() {
        guard pdfFocus.followsEvidence else { return }
        refocus()
    }

    private func refocus() {
        guard let e = navigator.currentEvidence else { return }  // branch cards keep the PDF where it is
        if let h = highlights[e] { pdfFocus.show(h) } else { highlights.resolve(e) }
    }

    // MARK: Answer Details

    var answerDetails: AnswerDetailsExport? {
        session.answer.map { AnswerDetailsExport(answer: $0, turns: session.turns, route: session.route, highlights: highlights) }
    }

    var routeLabel: String? { session.route?.label(serverHost: providers.serverHost) }

    /// Debug builds: the raw answer when it completes and each quote's match as it resolves.
    private func logAnswer() {
        #if DEBUG
        guard let d = answerDetails else { return }
        AnswerSession.log.debug("answer: \(d.json, privacy: .public)")
        #endif
    }

    private func logMatch(_ e: Evidence, _ h: Highlight) {
        #if DEBUG
        AnswerSession.log.debug("evidence p.\(e.page) \(h.match.result.rawValue, privacy: .public) [\(h.match.detail, privacy: .public)] rects=\(h.match.rects) quote=\(e.quote ?? "–", privacy: .public)")
        #endif
    }

    // MARK: Previews / screenshots

    /// Shows an answer without streaming (previews, `-present`). Highlights are placed synchronously.
    func present(_ live: LiveAnswer, phase: AnswerPhase) {
        session.present(live, phase: phase)
        sheetClosed = false
        for e in (live.steps + live.branches.flatMap(\.steps)).flatMap(\.evidence) {
            if let h = highlights.placeNow(e) { logMatch(e, h) }
        }
        logAnswer()
        navigator.cardID = nil
        navigator.rebuild()
    }
}
