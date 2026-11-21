import Foundation

// MARK: - Library

/// A game owns one or more documents (rulebook, later expansions / FAQ). UI shows one for now.
public struct Game: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var documents: [Document]

    public init(id: UUID = UUID(), name: String, documents: [Document]) {
        self.id = id
        self.name = name
        self.documents = documents
    }
}

public struct Document: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    /// Local file URL of the PDF.
    public var fileURL: URL

    public init(id: UUID = UUID(), title: String, fileURL: URL) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
    }
}

/// One game night: a conversation of questions/answers that carry context.
public struct Session: Codable, Sendable, Identifiable {
    public var id: UUID
    public var gameID: UUID
    public var startedAt: Date
    public var turns: [Turn]

    public init(id: UUID = UUID(), gameID: UUID, startedAt: Date = Date(), turns: [Turn] = []) {
        self.id = id
        self.gameID = gameID
        self.startedAt = startedAt
        self.turns = turns
    }
}

/// A question plus what came back. `rawAssistantText` is what gets replayed as conversation context.
public struct Turn: Codable, Sendable {
    public var question: String
    public var answer: Answer?
    public var rawAssistantText: String

    public init(question: String, answer: Answer?, rawAssistantText: String) {
        self.question = question
        self.answer = answer
        self.rawAssistantText = rawAssistantText
    }
}

// MARK: - Answer contract (SPEC §3). Property order == streaming order.

public enum Confidence: String, Codable, Sendable {
    case stated
    case inferred
    case notCovered = "not_covered"
}

public struct Answer: Codable, Sendable, Equatable {
    public var restatedQuestion: String
    public var verdict: String
    public var confidence: Confidence
    public var branches: [Branch]
    public var assumptions: [String]
    public var steps: [Step]
    public var needsWeb: Bool

    enum CodingKeys: String, CodingKey {
        case restatedQuestion = "restated_question"
        case verdict, confidence, branches, assumptions, steps
        case needsWeb = "needs_web"
    }

    public init(restatedQuestion: String, verdict: String, confidence: Confidence,
                branches: [Branch] = [], assumptions: [String] = [], steps: [Step] = [], needsWeb: Bool = false) {
        self.restatedQuestion = restatedQuestion
        self.verdict = verdict
        self.confidence = confidence
        self.branches = branches
        self.assumptions = assumptions
        self.steps = steps
        self.needsWeb = needsWeb
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        restatedQuestion = try c.decode(String.self, forKey: .restatedQuestion)
        verdict = try c.decode(String.self, forKey: .verdict)
        confidence = try c.decode(Confidence.self, forKey: .confidence)
        branches = try c.decodeIfPresent([Branch].self, forKey: .branches) ?? []
        assumptions = try c.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        steps = try c.decodeIfPresent([Step].self, forKey: .steps) ?? []
        needsWeb = try c.decodeIfPresent(Bool.self, forKey: .needsWeb) ?? (confidence != .stated)
    }
}

/// An alternative outcome when the verdict depends on something the player didn't say.
/// `steps` (usually one) carry the evidence for that case; answers from before the field
/// existed decode with none.
public struct Branch: Codable, Sendable, Equatable {
    public var condition: String
    public var verdict: String
    public var steps: [Step]

    public init(condition: String, verdict: String, steps: [Step] = []) {
        self.condition = condition
        self.verdict = verdict
        self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        condition = try c.decode(String.self, forKey: .condition)
        verdict = try c.decode(String.self, forKey: .verdict)
        steps = try c.decodeIfPresent([Step].self, forKey: .steps) ?? []
    }
}

public struct Step: Codable, Sendable, Equatable {
    /// Short label for the card caption ("General rule", "Battery exception"). Optional: older
    /// answers and the citations mode have none.
    public var title: String?
    public var text: String
    public var evidence: [Evidence]

    public init(title: String? = nil, text: String, evidence: [Evidence]) {
        self.title = title
        self.text = text
        self.evidence = evidence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decodeIfPresent(String.self, forKey: .title)?.trimmingCharacters(in: .whitespacesAndNewlines)
        title = (t?.isEmpty ?? true) ? nil : t
        text = try c.decode(String.self, forKey: .text)
        evidence = try c.decodeIfPresent([Evidence].self, forKey: .evidence) ?? []
    }

    /// Same step with every evidence item transformed (page remapping, normalization).
    public func mapEvidence(_ f: (Evidence) -> Evidence) -> Step {
        var s = self
        s.evidence = evidence.map(f)
        return s
    }
}

public struct Evidence: Codable, Sendable, Equatable {
    /// 1-based page number in the PDF.
    public var page: Int
    /// Exact passage from the page (to be matched to word coordinates). Empty for pure figures.
    public var quote: String?
    /// Optional figure region, normalized 0–1, origin top-left of the page.
    public var box: NormalizedBox?

    public init(page: Int, quote: String?, box: NormalizedBox? = nil) {
        self.page = page
        self.quote = quote
        self.box = box
    }
}

public struct NormalizedBox: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    public var area: Double { w * h }

    public func iou(_ o: NormalizedBox) -> Double {
        let ix = max(0, min(x + w, o.x + o.w) - max(x, o.x))
        let iy = max(0, min(y + h, o.y + o.h) - max(y, o.y))
        let inter = ix * iy
        let union = area + o.area - inter
        return union > 0 ? inter / union : 0
    }

    public var center: (Double, Double) { (x + w / 2, y + h / 2) }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px <= x + w && py >= y && py <= y + h
    }
}
