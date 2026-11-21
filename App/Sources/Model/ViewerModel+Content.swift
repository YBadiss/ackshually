import Foundation
import AckshuallyCore

/// Derives the plain view values from the live state.
extension ViewerModel {
    var header: HeaderContent? {
        guard let a = answer else { return nil }
        let state: HeaderContent.State
        if case .failed(let m) = phase { state = .failed(m) } else { state = a.verdict == nil ? .arriving : .answered }
        let branch = activeBranch.flatMap { a.branches[safe: $0] }
        return HeaderContent(state: state, question: a.restated ?? a.question,
                             verdict: branch?.verdict ?? a.verdict, confidence: a.confidence,
                             pages: branch.map { LiveAnswer.pages(of: $0.steps) } ?? a.pages,
                             condition: branch?.condition, isBusy: isBusy, stopped: a.stopped)
    }

    var cardItems: [CardItem] {
        guard let a = answer else { return [] }
        let ids = cards
        return ids.compactMap { id in
            switch id {
            case .step(let i):
                guard let s = a.steps[safe: i] else { return nil }
                return CardItem(id: id, content: Self.card(s, number: i + 1))
            case .branchStep(let b, let i):
                guard let s = a.branches[safe: b]?.steps[safe: i] else { return nil }
                return CardItem(id: id, content: Self.card(s, number: i + 1))
            case .loading:
                return CardItem(id: id, content: .loading(number: a.steps.count + 1))
            case .result:
                let text = activeBranch.flatMap { a.branches[safe: $0]?.verdict } ?? a.verdict ?? ""
                return CardItem(id: id, content: .result(number: ids.count, text: text, rating: currentRating))
            case .branch(let i):
                guard let b = a.branches[safe: i] else { return nil }
                return CardItem(id: id, content: .branch(condition: b.condition, verdict: b.verdict))
            }
        }
    }

    var stepRows: [StepRow] {
        (answer?.steps ?? []).enumerated().map {
            StepRow(index: $0, title: Self.stepTitle($1, number: $0 + 1), text: $1.text,
                    pages: $1.evidence.map(\.page).uniqued().sorted())
        }
    }

    var branchRows: [BranchRow] {
        (answer?.branches ?? []).enumerated().map {
            BranchRow(index: $0, condition: $1.condition, verdict: $1.verdict, isActive: activeBranch == $0)
        }
    }

    /// Caption title: the contract's `title`, else "Step N" (older answers, citations mode).
    static func stepTitle(_ s: Step, number: Int) -> String {
        s.title ?? "Step \(number)"
    }

    static func card(_ s: Step, number: Int) -> StepCardContent {
        .step(number: number, title: stepTitle(s, number: number), pages: s.evidence.map(\.page).uniqued(),
              text: s.text, figure: s.evidence.contains { $0.quote == nil })
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
