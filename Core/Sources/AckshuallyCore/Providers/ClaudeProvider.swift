import Foundation

/// How requests authenticate: straight to Anthropic with an API key (evals, local runs), or through the
/// ackshually server (`Server/`) with an app token, which holds the API key and forwards the same request.
public enum Credential: Sendable, Equatable {
    case apiKey(String)
    case appToken(String)
}

public struct ClaudeConfig: Sendable {
    public var credential: Credential
    public var model: String
    /// low | medium | high | xhigh | max. Mid-game latency matters, so bench defaults to "low".
    public var effort: String
    public var mode: EvidenceMode
    public var maxTokens: Int
    /// Use structured outputs (output_config.format) in json mode.
    public var useSchema: Bool
    /// Server-side refusal fallbacks (opus-5-5 / sonnet-5-5 only).
    public var useFallbacks: Bool
    /// api.anthropic.com for `.apiKey`; the ackshually server's URL for `.appToken`.
    public var baseURL: URL
    /// Idle timeout for the HTTP stream.
    public var requestTimeout: TimeInterval
    /// Prompt-cache lifetime for the rulebook prefix. Mid-game questions are often 5–60 min apart, so the
    /// default is 1 hour (write costs 2x input instead of 1.25x; pays off from the 3rd question).
    public var cacheTTL: CacheTTL

    public init(credential: Credential, model: String = "claude-sonnet-5-5", effort: String = "low", mode: EvidenceMode = .json,
                maxTokens: Int = 16000, useSchema: Bool = true, useFallbacks: Bool = true,
                baseURL: URL = URL(string: "https://api.anthropic.com")!, requestTimeout: TimeInterval = 120,
                cacheTTL: CacheTTL = .oneHour) {
        self.credential = credential
        self.model = model
        self.effort = effort
        self.mode = mode
        self.maxTokens = maxTokens
        self.useSchema = useSchema
        self.useFallbacks = useFallbacks
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.cacheTTL = cacheTTL
    }

    /// Direct to Anthropic with an API key.
    public init(apiKey: String, model: String = "claude-sonnet-5-5", effort: String = "low", mode: EvidenceMode = .json,
                maxTokens: Int = 16000, useSchema: Bool = true, useFallbacks: Bool = true,
                baseURL: URL = URL(string: "https://api.anthropic.com")!, requestTimeout: TimeInterval = 120,
                cacheTTL: CacheTTL = .oneHour) {
        self.init(credential: .apiKey(apiKey), model: model, effort: effort, mode: mode, maxTokens: maxTokens,
                  useSchema: useSchema, useFallbacks: useFallbacks, baseURL: baseURL, requestTimeout: requestTimeout,
                  cacheTTL: cacheTTL)
    }
}

public enum CacheTTL: String, Sendable {
    case fiveMinutes = "5m"
    case oneHour = "1h"

    /// `cache_control` value. Every marker in a request uses the same TTL (longer TTLs must come first).
    var cacheControl: JSONValue {
        switch self {
        case .fiveMinutes: return ["type": "ephemeral"]
        case .oneHour: return ["type": "ephemeral", "ttl": "1h"]
        }
    }
}

public struct ClaudeAPIError: Error, CustomStringConvertible, Sendable {
    public let status: Int
    public let body: String
    /// Seconds from the `retry-after` header (Anthropic's rate limits, the server's per-minute limit; the
    /// server's daily cap sends none).
    public let retryAfter: TimeInterval?

    public init(status: Int, body: String, retryAfter: TimeInterval? = nil) {
        self.status = status
        self.body = body
        self.retryAfter = retryAfter
    }

    public var description: String { "HTTP \(status): \(body.prefix(500))" }

    /// `error.type` and `error.message` of Anthropic's error shape (`{"type":"error","error":{…}}`), which the
    /// server uses too. Nil when the body is something else (a proxy's HTML page, an empty body).
    public var errorType: String? { errorField("type") }
    public var message: String? { errorField("message") }

    private func errorField(_ key: String) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let error = obj["error"] as? [String: Any] else { return nil }
        return error[key] as? String
    }
}

/// Full-PDF, single-call provider: builds the request and streams it. The PDF block carries a cache
/// breakpoint so follow-ups (and later questions on the same PDF) read it from cache; automatic caching
/// covers the growing tail. Page selection (an excerpt instead of the PDF) is `PageSelectingProvider`.
public final class ClaudeProvider: AnswerProvider, @unchecked Sendable {
    public let config: ClaudeConfig
    private let session: URLSession

    public init(config: ClaudeConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Largest PDF sent whole. The API takes 32 MB per request and base64 adds a third, so ~22 MB of PDF
    /// leaves room for the prompt and the conversation. Larger documents (several joined rulebooks) are sent
    /// as an excerpt of selected pages (`PageSelectingProvider`).
    public static let maxDocumentBytes = 22_000_000

    static let fallbackModels: Set<String> = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-opus-5", "claude-fable-5-2", "claude-fable-5-1"]

    // MARK: Request

    public func requestBody(for r: AnswerRequest) -> JSONValue {
        requestBody(for: r, excerpt: nil)
    }

    /// `excerpt` nil = the full PDF (M1 path, unchanged). `PageSelectingProvider` passes one.
    func requestBody(for r: AnswerRequest, excerpt: Excerpt?) -> JSONValue {
        let citations = config.mode == .citations
        var firstContent: [JSONValue] = []
        // Several books (S13): table of contents, order of authority, what is not in play. Before the
        // document, inside the cached prefix (stable for a given set of books).
        if let contents = r.contents, contents.needsPromptNote {
            firstContent.append(["type": "text", "text": .string(contents.promptNote)])
        }
        if let excerpt, let text = excerpt.text {
            firstContent.append(["type": "text", "text": .string(excerpt.note)])
            firstContent.append(["type": "text", "text": .string(text), "cache_control": config.cacheTTL.cacheControl])
        } else {
            let data = excerpt?.pdf ?? r.pdf
            var docBlock: [(String, JSONValue)] = [
                ("type", "document"),
                ("source", ["type": "base64", "media_type": "application/pdf", "data": .string(data.base64EncodedString())]),
                ("title", .string(excerpt == nil ? r.documentTitle : "\(r.documentTitle) (excerpt)")),
            ]
            if citations { docBlock.append(("citations", ["enabled": true])) }
            docBlock.append(("cache_control", config.cacheTTL.cacheControl))
            if let excerpt { firstContent.append(["type": "text", "text": .string(excerpt.note)]) }
            firstContent.append(.object(docBlock))
        }

        var messages: [JSONValue] = []
        let turns = r.history.map { ($0.question, $0.rawAssistantText) } + [(r.question, nil as String?)]
        for (i, (q, a)) in turns.enumerated() {
            if i == 0 {
                messages.append(["role": "user", "content": .array(firstContent + [["type": "text", "text": .string(q)]])])
            } else {
                messages.append(["role": "user", "content": .string(q)])
            }
            if let a { messages.append(["role": "assistant", "content": .string(a)]) }
        }

        var outputConfig: [(String, JSONValue)] = [("effort", .string(config.effort))]
        if config.mode == .json && config.useSchema {
            outputConfig.append(("format", ["type": "json_schema", "schema": Prompts.answerSchema]))
        }

        var body: [(String, JSONValue)] = [
            ("model", .string(config.model)),
            ("max_tokens", .int(config.maxTokens)),
            ("stream", true),
            ("system", .string(citations ? Prompts.citationsSystem : Prompts.jsonSystem)),
            ("output_config", .object(outputConfig)),
            ("cache_control", config.cacheTTL.cacheControl),
            ("messages", .array(messages)),
        ]
        if useFallbacks { body.append(("fallbacks", "default")) }
        return .object(body)
    }

    private var useFallbacks: Bool { config.useFallbacks && Self.fallbackModels.contains(config.model) }

    func urlRequest(for r: AnswerRequest, excerpt: Excerpt? = nil) -> URLRequest {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("v1/messages"))
        req.httpMethod = "POST"
        req.timeoutInterval = config.requestTimeout
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        switch config.credential {
        case .apiKey(let key): req.setValue(key, forHTTPHeaderField: "x-api-key")
        case .appToken(let token): req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        }
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        if useFallbacks { req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta") }
        req.httpBody = requestBody(for: r, excerpt: excerpt).data
        return req
    }

    // MARK: Streaming

    /// One call with the full PDF. `request.pageSelection` is ignored here: `PageSelectingProvider` wraps
    /// this provider to send only some pages.
    public func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
        let req = urlRequest(for: request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await self.stream(req) { continuation.yield($0); return true }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streams one request. `emit` returns false to stop early (the connection is dropped).
    /// Returns the usage seen so far.
    func stream(_ req: URLRequest, emit: (AnswerEvent) -> Bool) async throws -> TokenUsage {
        let (bytes, response) = try await session.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var body = ""
            for try await line in bytes.lines { body += line }
            let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
            throw ClaudeAPIError(status: status, body: body, retryAfter: retryAfter)
        }
        var parser = SSEAnswerParser(mode: config.mode, model: config.model)
        for try await line in bytes.lines {
            for e in try parser.consume(line: line) where !emit(e) { return parser.usage }
            if Task.isCancelled { return parser.usage }
        }
        for e in parser.finish() where !emit(e) { return parser.usage }
        return parser.usage
    }
}

/// Server-sent-events → AnswerEvents. Separate from networking so it can be unit-tested.
public struct SSEAnswerParser: Sendable {
    let mode: EvidenceMode
    var model: String
    var json = JSONAnswerAssembler()
    var cites = CitationsAnswerAssembler()
    public internal(set) var usage = TokenUsage()
    var stopReason: String?
    var sawText = false
    /// Content blocks that are visible text (thinking/fallback blocks are ignored).
    var textBlocks: Set<Int> = []
    var finished = false

    public init(mode: EvidenceMode, model: String) {
        self.mode = mode
        self.model = model
    }

    public mutating func consume(line: String) throws -> [AnswerEvent] {
        guard line.hasPrefix("data:") else { return [] }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return [] }
        switch type {
        case "message_start":
            if let m = obj["message"] as? [String: Any] {
                if let mm = m["model"] as? String { model = mm }
                if let u = m["usage"] as? [String: Any] { mergeUsage(u) }
            }
        case "content_block_start":
            if let idx = obj["index"] as? Int, let cb = obj["content_block"] as? [String: Any], cb["type"] as? String == "text" {
                textBlocks.insert(idx)
            }
        case "content_block_delta":
            guard let idx = obj["index"] as? Int, textBlocks.contains(idx),
                  let delta = obj["delta"] as? [String: Any], let dt = delta["type"] as? String else { return [] }
            var events: [AnswerEvent] = []
            if dt == "text_delta", let t = delta["text"] as? String {
                if !sawText { sawText = true; events.append(.firstToken) }
                switch mode {
                case .json: events += json.feed(t)
                case .citations: events += cites.feedText(block: idx, t)
                }
            } else if dt == "citations_delta", let c = delta["citation"] as? [String: Any],
                      c["type"] as? String == "page_location",
                      let cd = try? JSONSerialization.data(withJSONObject: c),
                      let pc = try? JSONDecoder().decode(PageCitation.self, from: cd) {
                cites.feedCitation(block: idx, pc)
            }
            return events
        case "message_delta":
            if let d = obj["delta"] as? [String: Any], let sr = d["stop_reason"] as? String { stopReason = sr }
            if let u = obj["usage"] as? [String: Any] { mergeUsage(u) }
        case "error":
            let e = (obj["error"] as? [String: Any])?["message"] as? String ?? payload
            throw ClaudeAPIError(status: 0, body: "stream error: \(e)")
        default:
            break
        }
        return []
    }

    public mutating func finish() -> [AnswerEvent] {
        guard !finished else { return [] }
        finished = true
        var events: [AnswerEvent] = []
        let raw: String
        let result: Result<Answer, AssemblyError>
        switch mode {
        case .json:
            raw = json.text
            result = json.finish()
        case .citations:
            raw = cites.text
            let f = cites.finish()
            events += f.events
            result = f.result
        }
        var parseError: String?
        var answer: Answer?
        switch result {
        case .success(let a): answer = a
        case .failure(let e): parseError = e.message
        }
        if let sr = stopReason, sr != "end_turn" {
            parseError = (parseError.map { $0 + "; " } ?? "") + "stop_reason=\(sr)"
        }
        events.append(.completed(AnswerResult(answer: answer, rawText: raw, usage: usage, model: model,
                                              stopReason: stopReason, parseError: parseError)))
        return events
    }

    private mutating func mergeUsage(_ u: [String: Any]) {
        if let v = u["input_tokens"] as? Int, v > 0 { usage.inputTokens = v }
        if let v = u["output_tokens"] as? Int, v > 0 { usage.outputTokens = v }
        if let v = u["cache_creation_input_tokens"] as? Int, v > 0 { usage.cacheCreationInputTokens = v }
        if let v = u["cache_read_input_tokens"] as? Int, v > 0 { usage.cacheReadInputTokens = v }
        if let c = u["cache_creation"] as? [String: Any], let v = c["ephemeral_1h_input_tokens"] as? Int, v > 0 {
            usage.cacheCreation1hInputTokens = v
        }
    }
}
