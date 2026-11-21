import Foundation

/// Two ways of getting evidence out of the model (compared in M1):
/// - `json`: model writes the SPEC §3 JSON itself, quotes included (structured outputs enforce the schema).
/// - `citations`: Claude's native PDF citations give page-located `cited_text`; the model writes a
///   line-based answer and we assemble the §3 contract from lines + citations. No figure boxes.
public enum EvidenceMode: String, Sendable, Codable, CaseIterable {
    case json
    case citations
}

enum Prompts {
    static let common = """
    You are a neutral board-game rules referee. Players are mid-game and the table is waiting: be fast, \
    precise and impartial. Answer the player's question using the attached rulebook PDF.

    Rules for the answer:
    - Restate the question in one short sentence, including the concrete situation, so the player can \
    tell immediately if you misunderstood.
    - Give the verdict first: one or two short sentences that settle the dispute.
    - confidence: "stated" if the rulebook says it explicitly; "inferred" if it follows from the rules \
    but is not written; "not_covered" if the rulebook does not settle it.
    - If the answer depends on facts the player did not give, give the most likely verdict and list \
    the alternatives as branches (condition → verdict).
    - Steps follow the logic of the ruling (general rule, then exceptions, then conclusion), not page \
    order. Use as many steps as needed, usually 2–4. Always check for exceptions, special cases and \
    clarifications elsewhere in the book before concluding.
    - Page numbers are the physical page index in the PDF file, starting at 1 for the first page of \
    the file. Do NOT use the page numbers printed on the pages.
    - In follow-up questions, use the earlier conversation as context.
    """

    static let jsonSystem = common + """

    - Each step cites evidence: the page and a quote copied verbatim from that page's text — one \
    contiguous span of 5–30 words, no ellipses, no paraphrase, no added punctuation.
    - If the evidence is a figure, diagram or illustration rather than text, set quote to "" (or a \
    caption copied verbatim if there is one) and give box: the figure's region as {x, y, w, h} \
    normalized to 0–1 with the origin at the top-left of the page. Otherwise box is null.
    - needs_web is true when confidence is not "stated".
    Output only the JSON object, keys in this order: restated_question, verdict, confidence, \
    branches, assumptions, steps, needs_web.
    """

    static let citationsSystem = common + """

    Write the answer as plain lines in exactly this format, one item per line, nothing else:
    QUESTION: <restated question>
    VERDICT: <verdict>
    CONFIDENCE: <stated|inferred|not_covered>
    BRANCH: <condition> => <verdict>        (zero or more lines)
    ASSUMPTION: <assumption>                (zero or more lines)
    STEP: <explanation of this step of the reasoning>, citing the rulebook passage that supports it
    STEP: ...                               (as many as needed)
    NEEDS_WEB: <yes|no>
    Every STEP line must cite the rulebook. Only STEP lines need citations.
    """

    /// JSON schema for structured outputs. Property order = streaming order.
    static let answerSchema: JSONValue = {
        let box: JSONValue = [
            "type": "object",
            "properties": ["x": ["type": "number"], "y": ["type": "number"], "w": ["type": "number"], "h": ["type": "number"]],
            "required": ["x", "y", "w", "h"],
            "additionalProperties": false,
        ]
        let evidence: JSONValue = [
            "type": "object",
            "properties": [
                "page": ["type": "integer"],
                "quote": ["type": "string"],
                "box": ["anyOf": [box, ["type": "null"]]],
            ],
            "required": ["page", "quote", "box"],
            "additionalProperties": false,
        ]
        let step: JSONValue = [
            "type": "object",
            "properties": ["text": ["type": "string"], "evidence": ["type": "array", "items": evidence]],
            "required": ["text", "evidence"],
            "additionalProperties": false,
        ]
        let branch: JSONValue = [
            "type": "object",
            "properties": ["condition": ["type": "string"], "verdict": ["type": "string"]],
            "required": ["condition", "verdict"],
            "additionalProperties": false,
        ]
        return [
            "type": "object",
            "properties": [
                "restated_question": ["type": "string"],
                "verdict": ["type": "string"],
                "confidence": ["type": "string", "enum": ["stated", "inferred", "not_covered"]],
                "branches": ["type": "array", "items": branch],
                "assumptions": ["type": "array", "items": ["type": "string"]],
                "steps": ["type": "array", "items": step],
                "needs_web": ["type": "boolean"],
            ],
            "required": ["restated_question", "verdict", "confidence", "branches", "assumptions", "steps", "needs_web"],
            "additionalProperties": false,
        ]
    }()
}
