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
    /// Part of `cacheCreationInputTokens` written with the 1-hour TTL (billed 2x input instead of 1.25x).
    public var cacheCreation1hInputTokens: Int = 0

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheCreationInputTokens: Int = 0, cacheReadInputTokens: Int = 0,
                cacheCreation1hInputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreation1hInputTokens = cacheCreation1hInputTokens
    }

    // Tolerant decoding: results recorded before the 1-hour field existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try c.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try c.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        cacheCreationInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens) ?? 0
        cacheReadInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens) ?? 0
        cacheCreation1hInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheCreation1hInputTokens) ?? 0
    }

    public static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(inputTokens: a.inputTokens + b.inputTokens,
                   outputTokens: a.outputTokens + b.outputTokens,
                   cacheCreationInputTokens: a.cacheCreationInputTokens + b.cacheCreationInputTokens,
                   cacheReadInputTokens: a.cacheReadInputTokens + b.cacheReadInputTokens,
                   cacheCreation1hInputTokens: a.cacheCreation1hInputTokens + b.cacheCreation1hInputTokens)
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
    /// Which pages were sent (nil when the request used the full document, the default).
    public var retrieval: RetrievalInfo?

    public init(answer: Answer?, rawText: String, usage: TokenUsage, model: String, stopReason: String?, parseError: String?,
                retrieval: RetrievalInfo? = nil) {
        self.answer = answer
        self.rawText = rawText
        self.usage = usage
        self.model = model
        self.stopReason = stopReason
        self.parseError = parseError
        self.retrieval = retrieval
    }
}

/// What page selection did for one answer. Evidence pages in the answer are already original pages.
public struct RetrievalInfo: Sendable, Codable, Equatable {
    /// Pages chosen for the first attempt (full document if retrieval gave up).
    public var selection: PageSelection
    public var representation: ExcerptRepresentation
    /// Size of what was attached on the first attempt (PDF bytes, or UTF-8 bytes of the text excerpt).
    public var excerptBytes: Int
    /// Local time spent indexing (first use of a PDF only), ranking and building the excerpt.
    public var prepareSeconds: Double
    /// The excerpt answered not_covered and the question was re-asked with the full PDF.
    public var fellBackToFullDocument: Bool
    /// Seconds after the request started when the fallback began.
    public var fallbackAfterSeconds: Double?
    /// Tokens spent on the discarded excerpt attempt (included in `AnswerResult.usage`).
    public var discardedUsage: TokenUsage?
    /// Model page numbers that were excerpt positions and got mapped to original pages.
    public var remappedPages: Int

    public init(selection: PageSelection, representation: ExcerptRepresentation, excerptBytes: Int, prepareSeconds: Double,
                fellBackToFullDocument: Bool = false, fallbackAfterSeconds: Double? = nil, discardedUsage: TokenUsage? = nil,
                remappedPages: Int = 0) {
        self.selection = selection
        self.representation = representation
        self.excerptBytes = excerptBytes
        self.prepareSeconds = prepareSeconds
        self.fellBackToFullDocument = fellBackToFullDocument
        self.fallbackAfterSeconds = fallbackAfterSeconds
        self.discardedUsage = discardedUsage
        self.remappedPages = remappedPages
    }
}

public struct AnswerRequest: Sendable {
    public var pdf: Data
    public var documentTitle: String
    public var question: String
    /// Prior turns in this session, oldest first.
    public var history: [Turn]
    /// Which pages to send. Default: the whole PDF (M1 behaviour). `.automatic` ranks pages locally
    /// and sends only the relevant ones (faster; see docs/speed-report.md).
    public var pageSelection: PageSelectionMode
    /// Optional prebuilt index of `pdf` (saves parsing it on the first question). Built and cached
    /// by the provider when nil.
    public var rulebook: RulebookIndex?
    /// The game's books in play (S13): `pdf` is them joined, and this is its table of contents and page map.
    /// nil = one rulebook and nothing else (the request is exactly the single-book one).
    public var contents: RulebookContents?

    public init(pdf: Data, documentTitle: String, question: String, history: [Turn] = [],
                pageSelection: PageSelectionMode = .fullDocument, rulebook: RulebookIndex? = nil,
                contents: RulebookContents? = nil) {
        self.pdf = pdf
        self.documentTitle = documentTitle
        self.question = question
        self.history = history
        self.pageSelection = pageSelection
        self.rulebook = rulebook
        self.contents = contents
    }

    /// The ticked books, joined (`RulebookJoiner`): the document is titled after the game.
    public init(books: JoinedRulebook, question: String, history: [Turn] = [],
                pageSelection: PageSelectionMode = .fullDocument, rulebook: RulebookIndex? = nil) {
        self.init(pdf: books.pdf, documentTitle: books.contents.gameTitle, question: question, history: history,
                  pageSelection: pageSelection, rulebook: rulebook,
                  contents: books.contents.needsPromptNote ? books.contents : nil)
    }

    /// Too large to attach whole (`ClaudeProvider.maxDocumentBytes`): only selected pages can be sent.
    public var isOversize: Bool { pdf.count > ClaudeProvider.maxDocumentBytes }
}

/// Provider-agnostic interface (SPEC §1 #15). App and bench use the same code path.
public protocol AnswerProvider: Sendable {
    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error>
}
