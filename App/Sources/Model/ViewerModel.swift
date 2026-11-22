import Foundation
import Observation
import AckshuallyCore

@MainActor
@Observable
final class ViewerModel {
    // Document
    private(set) var rulebook: LoadedRulebook?
    var openError: String?

    // Asking
    var draft = ""
    private(set) var turns: [Turn] = []

    // Answer
    private(set) var answer: LiveAnswer?
    private(set) var phase: AnswerPhase = .done
    private(set) var sheetVisible = false
    var detent: SheetDetent = .medium
    /// Step row the expanded answer scrolls to ("More" on a truncated card).
    private(set) var expandedRow: Int?
    /// Bound to the carousel's `.scrollPosition(id:)`.
    var cardID: CardID? {
        didSet { if cardID != oldValue { cardChanged() } }
    }
    private(set) var activeBranch: Int?
    private(set) var evidenceIndex = 0
    private(set) var zoom: ZoomMode = .evidence
    private(set) var focus: PDFFocus?
    /// Set by the PDF view when the user pinches/pans (shows "Back to Step N").
    var userMovedPDF = false
    /// Thumbs up/down per answer, in memory for M2 (S11 storage is M3).
    private(set) var feedback: [UUID: Bool] = [:]
    private(set) var isDemo = false
    /// Which route answered (or is answering) the current answer: Answer Details shows it.
    private(set) var route: AnswerRoute.Kind?
    /// The failure is fixed in Settings (rejected token or key): the error header offers it.
    private(set) var failureOpensSettings = false

    private var task: Task<Void, Never>?
    private(set) var highlights: [String: Highlight] = [:]
    private var resolving: Set<String> = []
    private var focusToken = 0

    // MARK: Document

    /// Loads a rulebook and resets the conversation. The library (My Games) decides what is
    /// remembered; this only opens.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let rb = LoadedRulebook(url: url) else {
            openError = "Couldn't open \(url.lastPathComponent) as a PDF."
            return false
        }
        reset()
        rulebook = rb
        return true
    }

    /// The open game was deleted from My Games.
    func close() {
        reset()
        rulebook = nil
    }

    private func reset() {
        cancel()
        turns = []
        answer = nil
        sheetVisible = false
        focus = nil
        highlights = [:]
        openError = nil
    }

    // MARK: Asking

    var isBusy: Bool { phase == .waiting || phase == .streaming }

    /// Follow-ups keep the conversation (Core replays prior turns).
    var canFollowUp: Bool {
        guard let a = answer, !isBusy else { return false }
        return a.complete || a.stopped || { if case .failed = phase { true } else { false } }()
    }

    /// Set when Settings should open: a real rulebook asked about without a credential, or a rejected
    /// credential. The screen opens Settings and clears it.
    var settingsRequested = false

    func requestSettings() { settingsRequested = true }

    func ask(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let rb = rulebook else { return }
        // Never answer a real rulebook with the scripted demo: keep the question and ask for a credential.
        guard let (provider, route) = Self.makeProvider(for: rb) else {
            draft = q
            settingsRequested = true
            return
        }
        cancel()
        draft = ""
        answer = LiveAnswer(question: q)
        phase = .waiting
        activeBranch = nil
        cardID = nil
        evidenceIndex = 0
        zoom = .evidence
        userMovedPDF = false
        // Spec S4: the sheet rises on the first token; until then the ask bar shows progress.
        sheetVisible = false
        detent = .medium

        isDemo = route == .demo
        self.route = route
        failureOpensSettings = false
        Self.log.debug("asking via \(route.rawValue, privacy: .public)")
        let request = AnswerRequest(pdf: rb.data, documentTitle: rb.title, question: q, history: turns)
        task = Task { [weak self] in
            do {
                for try await event in provider.answer(request) {
                    guard let self, !Task.isCancelled else { return }
                    self.handle(event)
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail(AnswerFailure(error, route: route))
            }
        }
    }

    /// Stop (S4): before any step arrives the question goes back into the field to rephrase.
    func stop() {
        guard isBusy else { return }
        cancel()
        if var a = answer, !a.steps.isEmpty {
            a.stopped = true
            answer = a
            phase = .done
            rebuildCardsIfNeeded()
        } else {
            draft = answer?.question ?? draft
            answer = nil
            sheetVisible = false
            phase = .done
        }
    }

    func dismissSheet() {
        if isBusy { stop() }
        sheetVisible = false
        focus = nil
        userMovedPDF = false
    }

    func showSheet() {
        guard answer != nil else { return }
        sheetVisible = true
        refocus()
    }

    func retry() {
        guard let q = answer?.question else { return }
        ask(q)
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }

    private func fail(_ failure: AnswerFailure) {
        failureOpensSettings = failure.opensSettings
        phase = .failed(failure.message)
        sheetVisible = true
    }

    private func handle(_ event: AnswerEvent) {
        guard var a = answer else { return }
        switch event {
        case .firstToken:
            phase = .streaming
            sheetVisible = true
        case .restatedQuestion(let s):
            a.restated = s
        case .verdict(let s):
            a.verdict = s
        case .confidence(let c):
            a.confidence = c
        case .branch(let b):
            a.branches.append(b)
        case .evidence(_, _, let e):
            resolve(e)
        case .step(let i, let s):
            if i < a.steps.count { a.steps[i] = s } else { a.steps.append(s) }
            for e in s.evidence { resolve(e) }
        case .completed(let r):
            if let final = r.answer {
                let done = LiveAnswer(question: a.question, answer: final)
                a = Self.merged(a, with: done)
                for e in final.steps.flatMap(\.evidence) { resolve(e) }
                turns.append(Turn(question: a.question, answer: final, rawAssistantText: r.rawText))
                phase = .done
                answer = a
                logAnswer()
            } else {
                answer = a
                fail(AnswerFailure(message: "The answer couldn't be read (\(r.parseError ?? "unknown error"))."))
                return
            }
        }
        sheetVisible = sheetVisible || phase == .streaming
        answer = a
        if case .step(let i, _) = event { rebuildCardsIfNeeded(newStep: i) } else { rebuildCardsIfNeeded() }
    }

    /// Keeps the answer's id (feedback and the carousel are keyed on it) while taking the final fields.
    private static func merged(_ old: LiveAnswer, with new: LiveAnswer) -> LiveAnswer {
        var a = old
        a.restated = new.restated; a.verdict = new.verdict; a.confidence = new.confidence
        a.branches = new.branches; a.assumptions = new.assumptions; a.steps = new.steps
        a.complete = true
        return a
    }

    // MARK: Cards

    var cards: [CardID] {
        guard let a = answer else { return [] }
        if let b = activeBranch, let branch = a.branches[safe: b] {
            if branch.steps.isEmpty { return [.branch(b)] }
            return branch.steps.indices.map { .branchStep(branch: b, step: $0) }
        }
        // No closing "Result" card: it only repeated the verdict. Feedback and the follow-up
        // field sit in their own row under the shelf.
        var c: [CardID] = a.steps.indices.map { .step($0) }
        if !(a.complete || a.stopped), a.verdict != nil { c.append(.loading) }
        return c
    }

    var currentCard: CardID? { cardID ?? cards.first }

    /// 1-based step number of the card the PDF follows (main answer or branch).
    var focusedStepNumber: Int? {
        switch currentCard {
        case .step(let i), .branchStep(_, let i): i + 1
        default: nil
        }
    }

    /// Index of the step on screen in the expanded step list (main answer or active branch).
    var focusedRow: Int? {
        switch currentCard {
        case .step(let i), .branchStep(_, let i): i
        default: nil
        }
    }

    /// Keeps the carousel on a valid card as cards stream in: step 1 becomes current when it
    /// arrives (S4: the PDF jumps to it); a reader parked on the loading card moves to the new step.
    private func rebuildCardsIfNeeded(newStep: Int? = nil) {
        let c = cards
        if cardID == .loading, let n = newStep { cardID = .step(n); return }
        if let id = cardID, c.contains(id) { return }
        if cardID == nil {
            if let f = c.first, f != .loading { cardID = f }
            return
        }
        cardID = cardID == .loading ? c.last : c.first
    }

    func select(_ card: CardID) {
        cardID = card
    }

    func selectStep(_ i: Int) {
        activeBranch = nil
        cardID = .step(i)
    }

    /// A row of the expanded step list: that step of whatever is shown (main answer or branch).
    func selectRow(_ i: Int) {
        if let b = activeBranch { cardID = .branchStep(branch: b, step: i) } else { cardID = .step(i) }
    }

    /// "More" on a truncated card: the expanded answer, scrolled to that step's full text.
    func showMore(_ card: CardID) {
        switch card {
        case .step(let i), .branchStep(_, let i): expandedRow = i
        default: expandedRow = nil
        }
        cardID = card
        detent = .expanded
    }

    func clearExpandedRow() { expandedRow = nil }

    func selectBranch(_ i: Int?) {
        activeBranch = i
        cardID = cards.first
    }

    private func cardChanged() {
        evidenceIndex = 0
        zoom = .evidence
        userMovedPDF = false
        refocus()
    }

    // MARK: PDF focus

    var currentStep: Step? {
        guard let a = answer else { return nil }
        switch currentCard {
        case .step(let i): return a.steps[safe: i]
        case .branchStep(let b, let i): return a.branches[safe: b]?.steps[safe: i]
        default: return nil
        }
    }

    var currentEvidence: Evidence? {
        guard let s = currentStep, s.evidence.indices.contains(evidenceIndex) else { return nil }
        return s.evidence[evidenceIndex]
    }

    var currentHighlight: Highlight? { currentEvidence.flatMap { highlights[Self.key($0)] } }

    func nextEvidence() {
        guard let s = currentStep, s.evidence.count > 1 else { return }
        evidenceIndex = (evidenceIndex + 1) % s.evidence.count
        zoom = .evidence
        userMovedPDF = false
        refocus()
    }

    func backToStep() {
        userMovedPDF = false
        zoom = .evidence
        refocus()
    }

    /// S8 double-tap: evidence zoom ↔ full page.
    func toggleZoom() {
        guard currentHighlight != nil else { return }
        zoom = (zoom == .evidence && !userMovedPDF) ? .page : .evidence
        userMovedPDF = false
        refocus()
    }

    /// Re-center after the visible area changes (sheet detent), unless the user is inspecting.
    func visibleAreaChanged() {
        guard !userMovedPDF, focus != nil else { return }
        refocus()
    }

    private func refocus() {
        guard let e = currentEvidence else { return }  // result/branch cards keep the PDF where it is
        if let h = highlights[Self.key(e)] {
            focusToken += 1
            focus = PDFFocus(token: focusToken, highlight: h, zoom: zoom)
        } else {
            resolve(e)
        }
    }

    static func key(_ e: Evidence) -> String {
        "\(e.page)|\(e.quote ?? "")|\(e.box.map { "\($0.x),\($0.y),\($0.w),\($0.h)" } ?? "")"
    }

    /// Quote → word rects via Core's QuoteMatcher, off the main thread (it may scan the whole book).
    private func resolve(_ e: Evidence) {
        let k = Self.key(e)
        guard highlights[k] == nil, !resolving.contains(k), let matcher = rulebook?.matcher else { return }
        resolving.insert(k)
        Task { [weak self] in
            let h = await Task.detached(priority: .userInitiated) { HighlightPlacer.place(e, matcher: matcher) }.value
            guard let self else { return }
            self.resolving.remove(k)
            self.highlights[k] = h
            self.logMatch(e, h)
            if let cur = self.currentEvidence, Self.key(cur) == k { self.refocus() }
        }
    }

    // MARK: Previews / screenshots

    /// Shows an answer without streaming (previews, UI screenshots). Highlights resolve synchronously.
    func present(_ live: LiveAnswer, phase: AnswerPhase, demo: Bool = true) {
        cancel()
        answer = live
        self.phase = phase
        isDemo = demo
        route = demo ? .demo : CredentialStore.route?.kind
        sheetVisible = true
        if let m = rulebook?.matcher {
            for e in (live.steps + live.branches.flatMap(\.steps)).flatMap(\.evidence) {
                let h = HighlightPlacer.place(e, matcher: m)
                highlights[Self.key(e)] = h
                logMatch(e, h)
            }
        }
        logAnswer()
        cardID = nil
        rebuildCardsIfNeeded()
    }

    // MARK: Feedback

    func rate(_ up: Bool) {
        guard let id = answer?.id else { return }
        feedback[id] = feedback[id] == up ? nil : up
    }

    var currentRating: Bool? { answer.flatMap { feedback[$0.id] } }

    // MARK: Provider

    /// Claude through the route the credentials give (token → server, else API key → direct); the scripted
    /// demo only for the sample rulebook (or `-demo YES`); nil for a real rulebook without a credential.
    static func makeProvider(for rulebook: LoadedRulebook) -> (AnswerProvider, route: AnswerRoute.Kind)? {
        let d = UserDefaults.standard
        if !d.bool(forKey: "demo"), let route = CredentialStore.route {
            let model = d.string(forKey: "model") ?? "claude-sonnet-5-5"
            return (ClaudeProvider(config: route.claudeConfig(model: model)), route.kind)
        }
        guard rulebook.isSample || d.bool(forKey: "demo") else { return nil }
        let scripted = d.string(forKey: "demoAnswer").flatMap(DemoProvider.answer(fromFile:)) ?? DemoProvider.batteryAnswer
        return (DemoProvider(answer: scripted), .demo)
    }
}
