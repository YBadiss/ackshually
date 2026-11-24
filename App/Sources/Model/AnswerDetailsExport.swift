import Foundation
import AckshuallyCore

/// What "Copy JSON" copies: the raw answer plus how each quote matched.
struct AnswerDetailsExport: Encodable {
    var question: String
    /// server | direct | demo
    var route: AnswerRoute.Kind?
    var answer: Answer?
    /// The model's literal output, when the answer came from Claude.
    var rawText: String?
    var evidence: [EvidenceReport]

    enum CodingKeys: String, CodingKey {
        case question, route, answer, evidence
        case rawText = "raw_text"
    }

    /// The shown answer: its final fields (once there is a verdict) and the raw text of the turn that produced it.
    @MainActor
    init(answer a: LiveAnswer, turns: [Turn], route: AnswerRoute.Kind?, highlights: HighlightStore, contents: RulebookContents? = nil) {
        question = a.question
        self.route = route
        answer = a.verdict.map {
            Answer(restatedQuestion: a.restated ?? a.question, verdict: $0, confidence: a.confidence ?? .notCovered,
                   branches: a.branches, assumptions: a.assumptions, steps: a.steps, needsWeb: a.confidence != .stated)
        }
        rawText = turns.last { $0.question == a.question }?.rawAssistantText
        evidence = EvidenceReport.reports(for: a, highlights: highlights, contents: contents)
    }

    var json: String {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
