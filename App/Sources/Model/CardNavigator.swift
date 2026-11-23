import Foundation
import Observation
import AckshuallyCore

/// Which card of the answer is on screen: the cards (main answer or the active branch, plus a loading card
/// while streaming), the current one, the branch selection, which quote of the step the PDF shows, and the
/// step the expanded answer scrolls to ("More"). Reads the answer from `AnswerSession`; reports card changes
/// through `onCardChange` so the coordinator can move the PDF.
@MainActor
@Observable
final class CardNavigator {
    /// Bound to the carousel's `.scrollPosition(id:)`.
    var cardID: CardID? {
        didSet {
            guard cardID != oldValue else { return }
            evidenceIndex = 0
            onCardChange()
        }
    }
    private(set) var activeBranch: Int?
    /// Which quote of the current step the PDF shows (the pager over the PDF).
    private(set) var evidenceIndex = 0
    /// Step row the expanded answer scrolls to ("More" on a truncated card).
    private(set) var expandedRow: Int?

    @ObservationIgnored var onCardChange: () -> Void = {}
    @ObservationIgnored private let session: AnswerSession

    init(session: AnswerSession) {
        self.session = session
    }

    // MARK: Cards

    var cards: [CardID] {
        guard let a = session.answer else { return [] }
        if let b = activeBranch, let branch = a.branches[safe: b] {
            if branch.steps.isEmpty { return [.branch(b)] }
            return branch.steps.indices.map { .branchStep(branch: b, step: $0) }
        }
        // No closing "Result" card: it only repeated the verdict. Feedback and the follow-up
        // field sit in their own row under the shelf.
        // While streaming, a loading card holds the shelf's place from the first token on, so the
        // sheet is sized once and content fills in place.
        var c: [CardID] = a.steps.indices.map { .step($0) }
        if session.isBusy, !(a.complete || a.stopped) { c.append(.loading) }
        return c
    }

    var currentCard: CardID? { cardID ?? cards.first }

    /// 1-based step number of the card the PDF follows (main answer or branch).
    var focusedStepNumber: Int? { focusedRow.map { $0 + 1 } }

    /// Index of the step on screen in the expanded step list (main answer or active branch).
    var focusedRow: Int? {
        switch currentCard {
        case .step(let i), .branchStep(_, let i): i
        default: nil
        }
    }

    var currentStep: Step? {
        guard let a = session.answer else { return nil }
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

    /// Keeps the carousel on a valid card as cards stream in: step 1 becomes current when it
    /// arrives (S4: the PDF jumps to it); a reader parked on the loading card moves to the new step.
    func rebuild(newStep: Int? = nil) {
        let c = cards
        if cardID == .loading, let n = newStep { cardID = .step(n); return }
        if let id = cardID, c.contains(id) { return }
        if cardID == nil {
            if let f = c.first, f != .loading { cardID = f }
            return
        }
        cardID = cardID == .loading ? c.last : c.first
    }

    /// A new question: back to the main answer, no card yet.
    func reset() {
        activeBranch = nil
        cardID = nil
        evidenceIndex = 0
    }

    // MARK: Selection

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

    func selectBranch(_ i: Int?) {
        activeBranch = i
        cardID = cards.first
    }

    /// "More" on a truncated card: that card, and the step the expanded answer scrolls to.
    func showMore(_ card: CardID) {
        switch card {
        case .step(let i), .branchStep(_, let i): expandedRow = i
        default: expandedRow = nil
        }
        cardID = card
    }

    func clearExpandedRow() { expandedRow = nil }

    // MARK: View values

    /// The answer header: the active branch's verdict and condition while one is shown.
    var header: HeaderContent? {
        guard let a = session.answer else { return nil }
        let state: HeaderContent.State
        if case .failed(let f) = session.phase { state = .failed(f) } else { state = a.verdict == nil ? .arriving : .answered }
        let branch = activeBranch.flatMap { a.branches[safe: $0] }
        return HeaderContent(state: state, question: a.restated ?? a.question,
                             verdict: branch?.verdict ?? a.verdict, confidence: a.confidence,
                             pages: branch.map { LiveAnswer.pages(of: $0.steps) } ?? a.pages,
                             condition: branch?.condition, isBusy: session.isBusy, stopped: a.stopped)
    }

    var cardItems: [CardItem] {
        guard let a = session.answer else { return [] }
        return cards.compactMap { id in
            switch id {
            case .step(let i):
                a.steps[safe: i].map { CardItem(id: id, content: .step($0, number: i + 1)) }
            case .branchStep(let b, let i):
                a.branches[safe: b]?.steps[safe: i].map { CardItem(id: id, content: .step($0, number: i + 1)) }
            case .loading:
                CardItem(id: id, content: .loading(number: a.steps.count + 1))
            case .branch(let i):
                a.branches[safe: i].map { CardItem(id: id, content: .branch(condition: $0.condition, verdict: $0.verdict)) }
            }
        }
    }

    /// Steps of what is shown: the active branch's, else the main answer's.
    var stepRows: [StepRow] {
        let a = session.answer
        let branchSteps = activeBranch.flatMap { a?.branches[safe: $0]?.steps }.flatMap { $0.isEmpty ? nil : $0 }
        return (branchSteps ?? a?.steps ?? []).enumerated().map {
            StepRow(index: $0, title: $1.displayTitle(number: $0 + 1), text: $1.text, pages: $1.citedPages.sorted())
        }
    }

    var branchRows: [BranchRow] {
        (session.answer?.branches ?? []).enumerated().map {
            BranchRow(index: $0, condition: $1.condition, verdict: $1.verdict, isActive: activeBranch == $0)
        }
    }

    // MARK: Quote pager

    /// The quote pager: the step's next passage (wraps). False when the step has only one.
    @discardableResult
    func nextEvidence() -> Bool {
        guard let s = currentStep, s.evidence.count > 1 else { return false }
        evidenceIndex = (evidenceIndex + 1) % s.evidence.count
        return true
    }
}
