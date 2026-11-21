import Foundation
import Observation
import AckshuallyCore

enum SheetDetent: CaseIterable { case collapsed, medium, expanded }

enum AnswerPhase: Equatable {
    /// Sent, nothing back yet (M1: first token ≈4–5 s on a full rulebook).
    case waiting
    case streaming
    case done
    case failed(String)
}

/// The answer as it streams in (spec §4 order) and once complete.
struct LiveAnswer: Identifiable {
    let id = UUID()
    var question: String
    var restated: String?
    var verdict: String?
    var confidence: Confidence?
    var branches: [Branch] = []
    var assumptions: [String] = []
    var steps: [Step] = []
    var complete = false
    var stopped = false

    /// Cited pages, ascending ("Stated in the rules · p.12, p.14").
    var pages: [Int] { Self.pages(of: steps) }

    static func pages(of steps: [Step]) -> [Int] { Array(Set(steps.flatMap { $0.evidence.map(\.page) })).sorted() }

    init(question: String) { self.question = question }

    init(question: String, answer a: Answer) {
        self.question = question
        restated = a.restatedQuestion
        verdict = a.verdict
        confidence = a.confidence
        branches = a.branches
        assumptions = a.assumptions
        steps = a.steps
        complete = true
    }
}

/// One card in the step carousel.
enum CardID: Hashable {
    case step(Int)
    /// Placeholder peeking while later steps stream.
    case loading
    /// Last card: result + thumbs up/down + follow-up.
    case result
    /// A branch without steps of its own (answers from before `branches[].steps`): one card.
    case branch(Int)
    /// Step `step` of branch `branch` (contract v2: a branch carries its own steps).
    case branchStep(branch: Int, step: Int)
}

enum ZoomMode { case evidence, page }

/// Where a piece of evidence lands on the PDF (spec §4 "Placing a highlight", M2 subset).
struct Highlight: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Word rects from QuoteMatcher (one per line).
        case words([NormalizedBox])
        /// Figure box outline.
        case box(NormalizedBox)
        /// No usable match/box: show the whole page.
        case wholePage
    }
    var page: Int
    var kind: Kind
    /// Small caption shown on the PDF, e.g. "See the figure on this page".
    var note: String?
}

/// What the PDF view should show now. A new `token` re-applies it (Back to step, double-tap).
struct PDFFocus: Equatable {
    var token: Int
    var highlight: Highlight
    var zoom: ZoomMode
}
