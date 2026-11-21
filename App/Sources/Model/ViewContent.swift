import Foundation
import AckshuallyCore

// Plain values the leaf views render. Built by `ViewerModel` (see ViewerModel+Content.swift) or
// by preview fixtures; views never reach into the model themselves.

/// Answer header (S4/S5): fixed while stepping.
struct HeaderContent: Equatable {
    enum State: Equatable {
        /// S4: nothing but the (restated) question yet.
        case arriving
        case answered
        case failed(String)
    }
    var state: State
    /// Restated question when known, else what the user asked.
    var question: String
    var verdict: String?
    var confidence: Confidence?
    var pages: [Int] = []
    var branches: [Branch] = []
    var activeBranch: Int?
    var isBusy = false
    var stopped = false
    var demo = false
}

/// A web finding (S10, M4). Rendered by StepCard already so the card family is designed together.
struct WebFinding: Equatable {
    var site: String
    var date: String
    var role: String
    var quote: String
    /// "⚠ Designer disagrees" (strong) / "⚠ Community disagrees" (soft).
    var warning: String?
}

/// One card of the step carousel.
enum StepCardContent: Equatable {
    case step(number: Int, title: String, pages: [Int], text: String, figure: Bool)
    case loading(number: Int)
    case result(number: Int, text: String, rating: Bool?)
    case branch(condition: String, verdict: String)
    case web(number: Int, WebFinding)
}

struct CardItem: Identifiable, Equatable {
    var id: CardID
    var content: StepCardContent
}

/// A row of the full-answer step list (S9).
struct StepRow: Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var text: String
    var pages: [Int]
}
