import Foundation
import AckshuallyCore

/// LLM-as-judge: compares the model's verdict with the expected one. Marked as such in the report.
struct Judge {
    let apiKey: String
    let model: String
    var baseURL = URL(string: "https://api.anthropic.com")!

    static let schema: JSONValue = [
        "type": "object",
        "properties": [
            "label": ["type": "string", "enum": ["correct", "partially_correct", "incorrect"]],
            "reason": ["type": "string"],
        ],
        "required": ["label", "reason"],
        "additionalProperties": false,
    ]

    /// `pageTexts`: text of the rulebook pages the answer cites plus the expected pages, so the judge
    /// can check extra claims against the source instead of treating anything outside the expected ruling as invented.
    func judge(question q: Question, answer a: Answer, pageTexts: [(page: Int, text: String)] = []) async -> Judgement? {
        let excerpts = pageTexts.map { "--- page \($0.page) ---\n\($0.text.prefix(6000))" }.joined(separator: "\n")
        let branches = a.branches.map { "- if \($0.condition): \($0.verdict)" }.joined(separator: "\n")
        let prompt = """
        You grade a board-game rules assistant. Compare its ruling with the expected ruling.
        "correct": same outcome for the situation asked (wording may differ; extra correct detail is fine).
        "partially_correct": right direction but misses or gets wrong an important condition/exception, \
        or only gives the right answer as a branch.
        "incorrect": different outcome, or claims the rulebook says something it does not.
        Use the RULEBOOK PAGES below to check any extra claims (branches, examples, exceptions). A claim supported \
        by those pages is fine even if the expected ruling does not mention it. Only treat a claim as invented if \
        it is absent from or contradicts the pages (PDF text may be scrambled by layout; read generously).
        If the expected ruling says the rulebook does not cover it, a response that clearly says so \
        (confidence not_covered or inferred, flagged as not stated) is correct.

        Question: \(q.question)
        Expected ruling: \(q.expectedVerdict)\(q.expectedConfidence.map { " (expected confidence: \($0))" } ?? "")

        Assistant verdict: \(a.verdict)
        Assistant confidence: \(a.confidence.rawValue)
        \(branches.isEmpty ? "" : "Assistant branches:\n\(branches)\n")Assistant reasoning steps:
        \(a.steps.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n"))

        RULEBOOK PAGES (text layer):
        \(excerpts.isEmpty ? "(none)" : excerpts)
        """
        let body: JSONValue = [
            "model": .string(model),
            "max_tokens": 4000,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": Judge.schema]],
            "messages": [["role": "user", "content": .string(prompt)]],
        ]
        var req = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        req.httpBody = body.data
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = obj["content"] as? [[String: Any]],
                  let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
                  let verdict = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                log("    judge failed: \(String(decoding: data, as: UTF8.self).prefix(300))")
                return nil
            }
            let u = obj["usage"] as? [String: Any] ?? [:]
            return Judgement(label: verdict["label"] as? String ?? "?", reason: verdict["reason"] as? String ?? "",
                             model: model,
                             usage: TokenUsage(inputTokens: u["input_tokens"] as? Int ?? 0, outputTokens: u["output_tokens"] as? Int ?? 0))
        } catch {
            log("    judge error: \(error)")
            return nil
        }
    }
}
