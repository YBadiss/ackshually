import Foundation

/// What the UI (or bench) receives while an answer streams. Order mirrors SPEC §3.
public enum AnswerEvent: Sendable {
    /// First output token of the visible answer (after any model thinking).
    case firstToken
    case restatedQuestion(String)
    case verdict(String)
    case confidence(Confidence)
    case branch(Branch)
    /// A single evidence item became available (step index, evidence index).
    case evidence(step: Int, index: Int, Evidence)
    case step(index: Int, Step)
    case completed(AnswerResult)
}

public struct TokenUsage: Codable, Sendable, Equatable {
    public var inputTokens: Int = 0
    public var outputTokens: Int = 0
    public var cacheCreationInputTokens: Int = 0
    public var cacheReadInputTokens: Int = 0

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheCreationInputTokens: Int = 0, cacheReadInputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }

    public static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(inputTokens: a.inputTokens + b.inputTokens,
                   outputTokens: a.outputTokens + b.outputTokens,
                   cacheCreationInputTokens: a.cacheCreationInputTokens + b.cacheCreationInputTokens,
                   cacheReadInputTokens: a.cacheReadInputTokens + b.cacheReadInputTokens)
    }
}

public struct AnswerResult: Sendable {
    /// Parsed answer, nil when output was invalid.
    public var answer: Answer?
    /// Visible text the model produced (replayed as conversation context for follow-ups).
    public var rawText: String
    public var usage: TokenUsage
    public var model: String
    public var stopReason: String?
    /// Set when the output could not be turned into an `Answer`.
    public var parseError: String?

    public init(answer: Answer?, rawText: String, usage: TokenUsage, model: String, stopReason: String?, parseError: String?) {
        self.answer = answer
        self.rawText = rawText
        self.usage = usage
        self.model = model
        self.stopReason = stopReason
        self.parseError = parseError
    }
}

public struct AnswerRequest: Sendable {
    public var pdf: Data
    public var documentTitle: String
    public var question: String
    /// Prior turns in this session, oldest first.
    public var history: [Turn]

    public init(pdf: Data, documentTitle: String, question: String, history: [Turn] = []) {
        self.pdf = pdf
        self.documentTitle = documentTitle
        self.question = question
        self.history = history
    }
}

/// Provider-agnostic interface (SPEC §1 #15). App and bench use the same code path.
public protocol AnswerProvider: Sendable {
    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error>
}
