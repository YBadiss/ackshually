import Foundation
import AckshuallyCore

/// Derives the plain view values from the live state.
extension ViewerModel {
    var header: HeaderContent? {
        guard let a = answer else { return nil }
        let state: HeaderContent.State
        if case .failed(let m) = phase { state = .failed(m) } else { state = a.verdict == nil ? .arriving : .answered }
        return HeaderContent(state: state, question: a.restated ?? a.question, verdict: a.verdict,
                             confidence: a.confidence, pages: a.pages, branches: a.branches,
                             activeBranch: activeBranch, isBusy: isBusy, stopped: a.stopped, demo: isDemo)
    }

    var cardItems: [CardItem] {
        guard let a = answer else { return [] }
        let ids = cards
        return ids.map { id in
            switch id {
            case .step(let i):
                let s = a.steps[i]
                return CardItem(id: id, content: .step(number: i + 1, title: Self.stepTitle(i, of: a.steps.count),
                                                       pages: s.evidence.map(\.page).uniqued(),
                                                       text: s.text, figure: s.evidence.contains { $0.quote == nil }))
            case .loading:
                return CardItem(id: id, content: .loading(number: a.steps.count + 1))
            case .result:
                let text = activeBranch.flatMap { a.branches[safe: $0]?.verdict } ?? a.verdict ?? ""
                return CardItem(id: id, content: .result(number: ids.count, text: text, rating: currentRating))
            case .branch(let i):
                let b = a.branches[i]
                return CardItem(id: id, content: .branch(condition: b.condition, verdict: b.verdict))
            }
        }
    }

    var stepRows: [StepRow] {
        (answer?.steps ?? []).enumerated().map { StepRow(index: $0, text: $1.text, pages: $1.evidence.map(\.page).uniqued().sorted()) }
    }

    /// Page shown in the collapsed bar ("✓ p.14").
    var collapsedPages: [Int] {
        if let p = currentHighlight?.page ?? currentEvidence?.page { return [p] }
        return answer?.pages ?? []
    }

    /// The contract has no step titles yet (docs/m2-notes.md proposes one); label by position.
    static func stepTitle(_ i: Int, of n: Int) -> String {
        n > 1 && i == 0 ? "Rule" : "Step"
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
