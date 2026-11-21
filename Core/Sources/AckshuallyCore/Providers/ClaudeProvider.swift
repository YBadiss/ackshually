import Foundation

public struct ClaudeConfig: Sendable {
    public var apiKey: String
    public var model: String
    /// low | medium | high | xhigh | max. Mid-game latency matters, so bench defaults to "low".
    public var effort: String
    public var mode: EvidenceMode
    public var maxTokens: Int
    /// Use structured outputs (output_config.format) in json mode.
    public var useSchema: Bool
    /// Server-side refusal fallbacks (opus-5-5 / sonnet-5-5 only).
    public var useFallbacks: Bool
    public var baseURL: URL
    /// Idle timeout for the HTTP stream.
    public var requestTimeout: TimeInterval

    public init(apiKey: String, model: String = "claude-sonnet-5-5", effort: String = "low", mode: EvidenceMode = .json,
                maxTokens: Int = 16000, useSchema: Bool = true, useFallbacks: Bool = true,
                baseURL: URL = URL(string: "https://api.anthropic.com")!, requestTimeout: TimeInterval = 120) {
        self.apiKey = apiKey
        self.model = model
        self.effort = effort
        self.mode = mode
        self.maxTokens = maxTokens
        self.useSchema = useSchema
        self.useFallbacks = useFallbacks
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
    }
}

public struct ClaudeAPIError: Error, CustomStringConvertible, Sendable {
    public let status: Int
    public let body: String
    public var description: String { "HTTP \(status): \(body.prefix(500))" }
}

/// Full-PDF, single-call provider. The PDF block carries a cache breakpoint so follow-ups (and
/// later questions on the same PDF) read it from cache; automatic caching covers the growing tail.
public final class ClaudeProvider: AnswerProvider, @unchecked Sendable {
    public let config: ClaudeConfig
    private let session: URLSession

    public init(config: ClaudeConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    static let fallbackModels: Set<String> = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-opus-5", "claude-fable-5-2", "claude-fable-5-1"]

    // MARK: Request

    public func requestBody(for r: AnswerRequest) -> JSONValue {
        requestBody(for: r, excerpt: nil)
    }

    /// `excerpt` nil = the full PDF (M1 path, unchanged).
    func requestBody(for r: AnswerRequest, excerpt: Excerpt?) -> JSONValue {
        let citations = config.mode == .citations
        var firstContent: [JSONValue] = []
        if let excerpt, let text = excerpt.text {
            firstContent.append(["type": "text", "text": .string(excerpt.note)])
            firstContent.append(["type": "text", "text": .string(text), "cache_control": ["type": "ephemeral"]])
        } else {
            let data = excerpt?.pdf ?? r.pdf
            var docBlock: [(String, JSONValue)] = [
                ("type", "document"),
                ("source", ["type": "base64", "media_type": "application/pdf", "data": .string(data.base64EncodedString())]),
                ("title", .string(excerpt == nil ? r.documentTitle : "\(r.documentTitle) (excerpt)")),
            ]
            if citations { docBlock.append(("citations", ["enabled": true])) }
            docBlock.append(("cache_control", ["type": "ephemeral"]))
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
            ("cache_control", ["type": "ephemeral"]),
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
        req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        if useFallbacks { req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta") }
        req.httpBody = requestBody(for: r, excerpt: excerpt).data
        return req
    }

    // MARK: Streaming

    public func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
        if case .fullDocument = request.pageSelection { return answerFull(request) }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.answerWithSelection(request) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// M1 path: one call with the full PDF.
    private func answerFull(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
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
    private func stream(_ req: URLRequest, emit: (AnswerEvent) -> Bool) async throws -> TokenUsage {
        let (bytes, response) = try await session.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var body = ""
            for try await line in bytes.lines { body += line }
            throw ClaudeAPIError(status: status, body: body)
        }
        var parser = SSEAnswerParser(mode: config.mode, model: config.model)
        for try await line in bytes.lines {
            for e in try parser.consume(line: line) where !emit(e) { return parser.usage }
            if Task.isCancelled { return parser.usage }
        }
        for e in parser.finish() where !emit(e) { return parser.usage }
        return parser.usage
    }

    // MARK: Page selection

    private var rulebooks: [Int: RulebookIndex] = [:]
    private let rulebookLock = NSLock()

    /// Parsed index for `pdf`, cached per provider (keyed by a hash of the bytes).
    func rulebook(for pdf: Data) -> RulebookIndex? {
        var h = Hasher()
        pdf.withUnsafeBytes { h.combine(bytes: $0) }
        let key = h.finalize()
        rulebookLock.lock()
        if let r = rulebooks[key] { rulebookLock.unlock(); return r }
        rulebookLock.unlock()
        guard let r = RulebookIndex(data: pdf) else { return nil }
        rulebookLock.lock()
        if rulebooks.count >= 4 { rulebooks.removeAll() }
        rulebooks[key] = r
        rulebookLock.unlock()
        return r
    }

    struct Excerpt {
        var selection: PageSelection
        var note: String
        var pdf: Data?
        var text: String?
        var bytes: Int { pdf?.count ?? text?.utf8.count ?? 0 }
    }

    /// Picks pages and builds the excerpt. nil = send the full PDF.
    func prepareExcerpt(_ r: AnswerRequest) -> (excerpt: Excerpt?, selection: PageSelection?, options: PageSelectionOptions) {
        var options = PageSelectionOptions(fallbackOnNotCovered: false)
        guard let book = r.rulebook ?? rulebook(for: r.pdf) else { return (nil, nil, options) }
        let selection: PageSelection
        switch r.pageSelection {
        case .fullDocument:
            return (nil, nil, options)
        case .automatic(let o):
            options = o
            selection = book.select(question: r.question, history: r.history, options: o)
        case .pages(let p, let rep):
            options.representation = rep
            selection = book.selection(pages: p)
        }
        // Citations on a text excerpt would locate characters, not pages: always send a PDF there.
        if config.mode == .citations { options.representation = .pdf }
        guard !selection.isFullDocument else { return (nil, selection, options) }
        let note = selection.excerptNote(title: r.documentTitle)
        switch options.representation {
        case .pdf:
            guard let data = book.excerptPDF(selection) else { return (nil, selection, options) }
            return (Excerpt(selection: selection, note: note, pdf: data), selection, options)
        case .text:
            return (Excerpt(selection: selection, note: note, text: book.excerptText(selection, title: r.documentTitle)), selection, options)
        }
    }

    private func answerWithSelection(_ r: AnswerRequest, yield: @escaping (AnswerEvent) -> Void) async throws {
        let start = Date()
        let (excerpt, selection, options) = prepareExcerpt(r)
        var info = RetrievalInfo(selection: selection ?? .full(pageCount: 0, reason: "PDF could not be parsed"),
                                 representation: options.representation, excerptBytes: excerpt?.bytes ?? r.pdf.count,
                                 prepareSeconds: Date().timeIntervalSince(start))
        let citations = config.mode == .citations
        var sentFirstToken = false

        // Full document (retrieval gave up): M1 path, plus the retrieval info.
        guard let excerpt else {
            _ = try await stream(urlRequest(for: r)) { e in
                if case .completed(var res) = e { res.retrieval = info; yield(.completed(res)) } else { yield(e) }
                return true
            }
            return
        }

        let sel = excerpt.selection
        func page(_ p: Int) -> Int {
            // Citations report positions in the attached (excerpt) PDF; json mode is asked for original pages.
            citations ? (sel.originalPage(excerptPage: p) ?? p) : sel.resolveModelPage(p)
        }
        func remap(_ st: Step) -> Step {
            Step(text: st.text, evidence: st.evidence.map { var x = $0; x.page = page(x.page); return x })
        }
        func remap(_ e: AnswerEvent) -> AnswerEvent {
            switch e {
            case .evidence(let s, let i, var ev): ev.page = page(ev.page); return .evidence(step: s, index: i, ev)
            case .step(let i, let st): return .step(index: i, remap(st))
            default: return e
            }
        }

        let fallback = options.fallbackOnNotCovered
        var held: [AnswerEvent] = []
        var decided = !fallback
        var notCovered = false
        let usage1 = try await stream(urlRequest(for: r, excerpt: excerpt)) { raw in
            var e = remap(raw)
            if case .completed(var res) = e {
                if let a = res.answer {
                    info.remappedPages = a.steps.flatMap(\.evidence).filter { page($0.page) != $0.page }.count
                    var m = a
                    m.steps = a.steps.map(remap)
                    res.answer = m
                }
                if res.answer?.confidence == .notCovered && fallback && !decided { notCovered = true; return false }
                res.retrieval = info
                e = .completed(res)
            }
            if case .firstToken = e { sentFirstToken = true; yield(e); return true }
            if !decided {
                if case .confidence(let c) = e {
                    if c == .notCovered { notCovered = true; return false }
                    decided = true
                    held.forEach(yield)
                    held.removeAll()
                    yield(e)
                } else if case .completed = e {
                    decided = true
                    held.forEach(yield)
                    yield(e)
                } else {
                    held.append(e)
                }
                return true
            }
            yield(e)
            return true
        }
        guard notCovered, !Task.isCancelled else { return }

        // The excerpt did not settle it: re-ask with the full PDF.
        info.fellBackToFullDocument = true
        info.fallbackAfterSeconds = Date().timeIntervalSince(start)
        info.discardedUsage = usage1
        _ = try await stream(urlRequest(for: r)) { e in
            switch e {
            case .firstToken:
                if !sentFirstToken { sentFirstToken = true; yield(e) }
            case .completed(var res):
                res.usage = res.usage + usage1
                res.retrieval = info
                yield(.completed(res))
            default:
                yield(e)
            }
            return true
        }
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
    }
}
