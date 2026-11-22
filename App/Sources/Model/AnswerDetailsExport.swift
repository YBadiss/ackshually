import Foundation
import AckshuallyCore

/// What "Copy JSON" copies: the raw answer plus how each quote matched.
struct AnswerDetailsExport: Encodable {
    var question: String
    var answer: Answer?
    /// The model's literal output, when the answer came from Claude.
    var rawText: String?
    var evidence: [EvidenceReport]

    enum CodingKeys: String, CodingKey {
        case question, answer, evidence
        case rawText = "raw_text"
    }

    var json: String {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
