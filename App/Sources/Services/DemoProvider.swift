import Foundation
import AckshuallyCore

/// Scripted provider for previews, screenshots and running without an API key. Streams a fixed
/// answer with realistic delays (M1: restated question ≈4 s, step 1 ≈6 s; compressed here).
struct DemoProvider: AnswerProvider {
    var answer: Answer
    /// Multiplier on the scripted delays (0 = instant, for previews).
    var pace: Double = 1

    static let batteryAnswer = Answer(
        restatedQuestion: "You have 3 unused energy and a Battery at the end of your turn.",
        verdict: "Keep 2 energy on the Battery, discard 1.",
        confidence: .stated,
        branches: [Branch(condition: "Without a Battery", verdict: "Discard all 3.", steps: [
            Step(title: "General rule", text: "Without a Battery nothing is kept: all unused energy is discarded at the end of your turn.",
                 evidence: [Evidence(page: 3, quote: "at the end of your turn you must discard all unused energy")]),
        ])],
        assumptions: ["The Battery is already one of your plants."],
        steps: [
            Step(title: "General rule", text: "Unused energy is discarded during Clean-up, at the end of your turn.",
                 evidence: [Evidence(page: 3, quote: "at the end of your turn you must discard all unused energy")]),
            Step(title: "Battery exception", text: "A Battery keeps up to 2 unused energy instead of discarding them.",
                 evidence: [Evidence(page: 4, quote: "a player who owns a Battery keeps up to 2 unused energy instead of discarding them")]),
            Step(title: "What's left over", text: "Anything above 2 is still discarded, so 1 of your 3 energy goes back to the supply.",
                 evidence: [Evidence(page: 4, quote: "Any additional energy is discarded as normal"),
                            Evidence(page: 3, quote: "Discarded energy cubes return to the general supply")]),
        ],
        needsWeb: false)

    /// Loads an `Answer` JSON (spec §4 contract) for scripted demos on a real rulebook.
    static func answer(fromFile path: String) -> Answer? {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Answer.self, from: d)
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
        let a = answer
        let pace = pace
        return AsyncThrowingStream { c in
            let task = Task {
                func wait(_ s: Double) async throws { if pace > 0 { try await Task.sleep(for: .seconds(s * pace)) } }
                do {
                    try await wait(1.2); c.yield(.firstToken)
                    try await wait(0.4); c.yield(.restatedQuestion(a.restatedQuestion))
                    try await wait(0.9); c.yield(.verdict(a.verdict))
                    try await wait(0.1); c.yield(.confidence(a.confidence))
                    for (i, s) in a.steps.enumerated() {
                        try await wait(i == 0 ? 1.0 : 0.8)
                        for (j, e) in s.evidence.enumerated() { c.yield(.evidence(step: i, index: j, e)) }
                        c.yield(.step(index: i, s))
                    }
                    // Same order as the real contract (spec §4): branches after the steps.
                    try await wait(0.4)
                    for b in a.branches { c.yield(.branch(b)) }
                    let raw = (try? JSONEncoder().encode(a)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    c.yield(.completed(AnswerResult(answer: a, rawText: raw, usage: TokenUsage(), model: "demo",
                                                    stopReason: "end_turn", parseError: nil)))
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }
}
