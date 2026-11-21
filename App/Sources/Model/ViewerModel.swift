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

    private var task: Task<Void, Never>?
    private var highlights: [String: Highlight] = [:]
    private var resolving: Set<String> = []
    private var focusToken = 0

    // MARK: Document

    func open(_ url: URL, remember: Bool = true) {
        guard let rb = LoadedRulebook(url: url) else {
            openError = "Couldn't open \(url.lastPathComponent) as a PDF."
            return
        }
        cancel()
        rulebook = rb
        turns = []
        answer = nil
        sheetVisible = false
        focus = nil
        highlights = [:]
        openError = nil
        if remember { Library.remember(url) }
    }

    func importPicked(_ url: URL) {
        do { open(try Library.importPDF(from: url)) } catch { openError = "Import failed: \(error.localizedDescription)" }
    }

    func openSample() {
        do { open(try Library.sampleRulebook()) } catch { openError = "\(error)" }
    }

    // MARK: Asking

    var isBusy: Bool { phase == .waiting || phase == .streaming }

    /// Follow-ups keep the conversation (Core replays prior turns).
    var canFollowUp: Bool {
        guard let a = answer, !isBusy else { return false }
        return a.complete || a.stopped || { if case .failed = phase { true } else { false } }()
    }

    func ask(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let rb = rulebook else { return }
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

        let (provider, demo) = Self.makeProvider()
        isDemo = demo
        let request = AnswerRequest(pdf: rb.data, documentTitle: rb.title, question: q, history: turns)
        task = Task { [weak self] in
            do {
                for try await event in provider.answer(request) {
                    guard let self, !Task.isCancelled else { return }
                    self.handle(event)
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail(Self.describe(error))
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

    private func fail(_ message: String) {
        phase = .failed(message)
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
            } else {
                answer = a
                fail("The answer couldn't be read (\(r.parseError ?? "unknown error")).")
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
            if branch.steps.isEmpty { return [.branch(b), .result] }
            return branch.steps.indices.map { .branchStep(branch: b, step: $0) } + [.result]
        }
        var c: [CardID] = a.steps.indices.map { .step($0) }
        if a.complete || a.stopped {
            c.append(.result)
        } else if a.verdict != nil {
            c.append(.loading)
        }
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

    /// Index of the main-answer step on screen (the expanded step list marks it).
    var focusedMainStep: Int? {
        if case .step(let i) = currentCard { return i }
        return nil
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

    private static func key(_ e: Evidence) -> String {
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
        sheetVisible = true
        if let m = rulebook?.matcher {
            for e in (live.steps + live.branches.flatMap(\.steps)).flatMap(\.evidence) { highlights[Self.key(e)] = HighlightPlacer.place(e, matcher: m) }
        }
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

    static func makeProvider() -> (AnswerProvider, demo: Bool) {
        let d = UserDefaults.standard
        if !d.bool(forKey: "demo"), let key = APIKeyStore.current {
            let model = d.string(forKey: "model") ?? "claude-sonnet-5-5"
            return (ClaudeProvider(config: ClaudeConfig(apiKey: key, model: model, effort: "low", mode: .json)), false)
        }
        let scripted = d.string(forKey: "demoAnswer").flatMap(DemoProvider.answer(fromFile:)) ?? DemoProvider.batteryAnswer
        return (DemoProvider(answer: scripted), true)
    }

    static func describe(_ error: Error) -> String {
        if let e = error as? ClaudeAPIError {
            switch e.status {
            case 401: return "The API key was rejected. Check it in Settings."
            case 429: return "Rate limited. Try again in a moment."
            case 529, 503: return "Claude is overloaded. Try again in a moment."
            default: return e.description
            }
        }
        if let u = error as? URLError {
            return u.code == .notConnectedToInternet ? "No internet connection." : u.localizedDescription
        }
        return error.localizedDescription
    }
}
