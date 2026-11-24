import Foundation
import Observation
import OSLog
import AckshuallyCore

/// One game's conversation: asking, streaming events into a `LiveAnswer`, stop, retry, follow-ups (Core
/// replays `turns`), failures and feedback. Where answers come from is injected (`AnswerProviderFactory`), so
/// all of this runs in unit tests with a scripted provider. Knows nothing about cards, the PDF or the sheet:
/// it reports what changed through `onChange` and `ViewerModel` reacts.
@MainActor
@Observable
final class AnswerSession {
    /// What a call or a streamed event changed, for the coordinator.
    enum Change: Equatable {
        /// A new question went out (the previous answer is replaced).
        case started
        /// A real rulebook asked about without a credential: Settings should open (the question is kept).
        case needsCredential
        /// Evidence that will be shown: resolve its highlights.
        case evidence([Evidence])
        /// Step `index` arrived (the carousel may move onto it).
        case step(Int)
        /// The books in play changed (S13): the document, its matcher and the conversation are new.
        case rulebookChanged
        /// Any other field of the answer.
        case updated
        case completed
        case failed
        case stopped
    }

    var draft = ""
    private(set) var turns: [Turn] = []
    private(set) var answer: LiveAnswer?
    private(set) var phase: AnswerPhase = .done
    /// Which route answered (or is answering) the current answer: Answer Details shows it.
    private(set) var route: AnswerRoute.Kind?
    /// Thumbs up/down per answer, in memory for M2 (S11 storage is M3).
    private(set) var feedback: [UUID: Bool] = [:]

    /// The document answers use and the viewer shows: the game's books in play.
    private(set) var rulebook: LoadedRulebook
    /// The next books in play while they load or wait for the next question (S13: a change applies from the
    /// next question; the answer on screen stays with the document it cites).
    private(set) var staged: Task<LoadedRulebook?, Never>?

    @ObservationIgnored var onChange: (Change) -> Void = { _ in }
    @ObservationIgnored private let providers: any AnswerProviderFactory
    @ObservationIgnored private var task: Task<Void, Never>?

    init(rulebook: LoadedRulebook, providers: any AnswerProviderFactory) {
        self.rulebook = rulebook
        self.providers = providers
    }

    // MARK: Books in play (S13)

    /// Changes the books in play. With nothing on screen the new document is shown as soon as it is loaded;
    /// otherwise the current answer stays and the next question uses (and shows) the new books.
    func stage(_ load: Task<LoadedRulebook?, Never>) {
        staged = load
        Task { [weak self] in
            let rb = await load.value
            guard let self, self.staged == load, let rb else { return }
            if self.answer == nil && !self.isBusy { self.apply(rb) }
        }
    }

    private func apply(_ rb: LoadedRulebook) {
        staged = nil
        guard rb !== rulebook else { return }
        rulebook = rb
        // Earlier turns cite pages of the old document and were answered without (or with) other books:
        // a new set of books starts a new conversation.
        turns = []
        onChange(.rulebookChanged)
    }

    var isDemo: Bool { route == .demo }

    var isBusy: Bool { phase == .waiting || phase == .streaming }

    /// Follow-ups keep the conversation (Core replays prior turns).
    var canFollowUp: Bool {
        guard let a = answer, !isBusy else { return false }
        return a.complete || a.stopped || { if case .failed = phase { true } else { false } }()
    }

    var currentRating: Bool? { answer.flatMap { feedback[$0.id] } }

    // MARK: Asking

    func ask(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        let pending = staged
        // Never answer a real rulebook with the scripted demo: keep the question and ask for a credential.
        // (A staged change keeps the game's books, so whether it is the sample doesn't change.)
        guard let (provider, route) = providers.provider(isSample: rulebook.isSample) else {
            draft = q
            onChange(.needsCredential)
            return
        }
        cancel()
        draft = ""
        answer = LiveAnswer(question: q)
        // Spec S4: the sheet rises on the first token; until then the ask bar shows progress.
        phase = .waiting
        self.route = route
        onChange(.started)
        Self.log.debug("asking via \(route.rawValue, privacy: .public)")
        task = Task { [weak self] in
            // The books ticked since the last answer: wait for them (joining takes a moment), then show them.
            if let pending, let rb = await pending.value, let self, !Task.isCancelled, self.staged == pending { self.apply(rb) }
            guard !Task.isCancelled, let request = self?.request(for: q) else { return }
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

    /// The question about the books in play, after the conversation so far.
    private func request(for q: String) -> AnswerRequest {
        AnswerRequest(pdf: rulebook.data, documentTitle: rulebook.title, question: q, history: turns,
                      rulebook: rulebook.index, contents: rulebook.contents.needsPromptNote ? rulebook.contents : nil)
    }

    /// Stop (S4): before any step arrives the question goes back into the field to rephrase.
    func stop() {
        guard isBusy else { return }
        cancel()
        if var a = answer, !a.steps.isEmpty {
            a.stopped = true
            answer = a
        } else {
            draft = answer?.question ?? draft
            answer = nil
        }
        phase = .done
        onChange(.stopped)
    }

    func retry() {
        guard let q = answer?.question else { return }
        ask(q)
    }

    func rate(_ up: Bool) {
        guard let id = answer?.id else { return }
        feedback[id] = feedback[id] == up ? nil : up
    }

    /// Shows an answer without streaming (previews, `-present`), as if `route` had answered it.
    func present(_ live: LiveAnswer, phase: AnswerPhase, route: AnswerRoute.Kind? = .demo) {
        cancel()
        answer = live
        self.phase = phase
        self.route = route
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: Events

    private func fail(_ failure: AnswerFailure) {
        phase = .failed(failure)
        onChange(.failed)
    }

    private func handle(_ event: AnswerEvent) {
        guard var a = answer else { return }
        var change = Change.updated
        switch event {
        case .firstToken:
            phase = .streaming
        case .restatedQuestion(let s):
            a.restated = s
        case .verdict(let s):
            a.verdict = s
        case .confidence(let c):
            a.confidence = c
        case .branch(let b):
            a.branches.append(b)
        case .evidence(_, _, let e):
            onChange(.evidence([e]))
        case .step(let i, let s):
            if i < a.steps.count { a.steps[i] = s } else { a.steps.append(s) }
            answer = a
            onChange(.evidence(s.evidence))
            change = .step(i)
        case .completed(let r):
            guard let final = r.answer else {
                answer = a
                fail(AnswerFailure(message: "The answer couldn't be read (\(r.parseError ?? "unknown error"))."))
                return
            }
            a = Self.merged(a, with: LiveAnswer(question: a.question, answer: final))
            turns.append(Turn(question: a.question, answer: final, rawAssistantText: r.rawText))
            phase = .done
            answer = a
            onChange(.evidence(final.steps.flatMap(\.evidence)))
            change = .completed
        }
        answer = a
        onChange(change)
    }

    /// Keeps the answer's id (feedback and the carousel are keyed on it) while taking the final fields.
    private static func merged(_ old: LiveAnswer, with new: LiveAnswer) -> LiveAnswer {
        var a = old
        a.restated = new.restated; a.verdict = new.verdict; a.confidence = new.confidence
        a.branches = new.branches; a.assumptions = new.assumptions; a.steps = new.steps
        a.complete = true
        return a
    }

    static let log = Logger(subsystem: "app.ackshually.viewer", category: "answer")
}
