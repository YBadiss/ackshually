import Foundation

extension ClaudeProvider {
    /// The pages sent instead of the full PDF: a sub-PDF or their text, with a note saying what they are.
    struct Excerpt {
        var selection: PageSelection
        var note: String
        var pdf: Data?
        var text: String?
        var bytes: Int { pdf?.count ?? text?.utf8.count ?? 0 }
    }
}

/// Page selection (the parked speed experiment, `bench --pages auto`): ranks the rulebook's pages locally,
/// sends `base` an excerpt instead of the full PDF, maps the answer's pages back to the book's, and (when
/// asked) re-asks with the full PDF if the excerpt answered not_covered. A request with
/// `.fullDocument` (the app's default) goes straight to `base`, unchanged.
public final class PageSelectingProvider: AnswerProvider, @unchecked Sendable {
    public let base: ClaudeProvider
    private var rulebooks: [Int: RulebookIndex] = [:]
    private let rulebookLock = NSLock()

    public init(base: ClaudeProvider) {
        self.base = base
    }

    private var config: ClaudeConfig { base.config }

    // MARK: Request (same body as `base`, for tests and bench dumps)

    public func requestBody(for r: AnswerRequest) -> JSONValue { base.requestBody(for: r) }

    func requestBody(for r: AnswerRequest, excerpt: ClaudeProvider.Excerpt?) -> JSONValue {
        base.requestBody(for: r, excerpt: excerpt)
    }

    // MARK: Streaming

    /// Page selection for a document too large to send whole (several joined rulebooks, S13): generous, and
    /// never the full PDF (it would be refused), so no full-document fallback either.
    public static let oversizeOptions = PageSelectionOptions(topK: 6, neighbors: 1, maxPages: 16, fullIfCoverage: 2,
                                                             fallbackOnNotCovered: false)

    /// What `request` will send: its own choice, except that a document over `ClaudeProvider.maxDocumentBytes`
    /// is never sent whole.
    public static func effectiveSelection(for request: AnswerRequest) -> PageSelectionMode {
        guard request.isOversize else { return request.pageSelection }
        switch request.pageSelection {
        case .fullDocument: return .automatic(oversizeOptions)
        case .automatic(var o):
            o.fallbackOnNotCovered = false
            o.fullIfCoverage = 2
            if o.maxPages == nil { o.maxPages = oversizeOptions.maxPages }
            return .automatic(o)
        case .pages: return request.pageSelection
        }
    }

    public func answer(_ original: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
        let request = { var r = original; r.pageSelection = Self.effectiveSelection(for: original); return r }()
        if case .fullDocument = request.pageSelection { return base.answer(request) }
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

    // MARK: Page selection

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

    /// Picks pages and builds the excerpt. nil = send the full PDF.
    func prepareExcerpt(_ r: AnswerRequest) -> (excerpt: ClaudeProvider.Excerpt?, selection: PageSelection?, options: PageSelectionOptions) {
        var options = PageSelectionOptions(fallbackOnNotCovered: false)
        guard let book = r.rulebook ?? rulebook(for: r.pdf) else { return (nil, nil, options) }
        var selection: PageSelection
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
        if selection.isFullDocument && r.isOversize {
            // The whole document would be refused: send its best-ranked pages (or its first ones) instead.
            let cap = options.maxPages ?? Self.oversizeOptions.maxPages ?? 16
            let pages = selection.ranked.isEmpty ? Array(1...min(cap, book.pageCount)) : Array(selection.ranked.prefix(cap))
            var s = book.selection(pages: pages)
            s.ranked = selection.ranked
            s.confidence = selection.confidence
            s.reason = "document too large to send whole" + (selection.reason.map { " (\($0))" } ?? "")
            selection = s
        }
        guard !selection.isFullDocument else { return (nil, selection, options) }
        let note = selection.excerptNote(title: r.documentTitle, fullDocumentFollows: options.fallbackOnNotCovered)
        switch options.representation {
        case .pdf:
            guard let data = book.excerptPDF(selection) else { return (nil, selection, options) }
            return (ClaudeProvider.Excerpt(selection: selection, note: note, pdf: data), selection, options)
        case .text:
            return (ClaudeProvider.Excerpt(selection: selection, note: note, text: book.excerptText(selection, title: r.documentTitle)),
                    selection, options)
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
            _ = try await base.stream(base.urlRequest(for: r)) { e in
                if case .completed(var res) = e { res.retrieval = info; yield(.completed(res)) } else { yield(e) }
                return true
            }
            return
        }

        let sel = excerpt.selection
        let book = r.rulebook ?? rulebook(for: r.pdf)
        var resolved: [String: Int] = [:]
        func page(_ e: Evidence) -> Int {
            // Citations report positions in the attached (excerpt) PDF; json mode is asked for original
            // pages but can mis-number them, so quotes are checked against the selected pages' text.
            let key = "\(e.page)|\(e.quote ?? "")"
            if let p = resolved[key] { return p }
            let p = book?.resolvePage(e, in: sel, excerptPositions: citations)
                ?? (citations ? (sel.originalPage(excerptPage: e.page) ?? e.page) : sel.resolveModelPage(e.page))
            resolved[key] = p
            return p
        }
        func remap(_ st: Step) -> Step {
            st.mapEvidence { var x = $0; x.page = page(x); return x }
        }
        func remap(_ b: Branch) -> Branch {
            var x = b; x.steps = b.steps.map(remap); return x
        }
        func remap(_ e: AnswerEvent) -> AnswerEvent {
            switch e {
            case .evidence(let s, let i, var ev): ev.page = page(ev); return .evidence(step: s, index: i, ev)
            case .step(let i, let st): return .step(index: i, remap(st))
            case .branch(let b): return .branch(remap(b))
            default: return e
            }
        }

        let fallback = options.fallbackOnNotCovered
        var held: [AnswerEvent] = []
        var decided = !fallback
        var notCovered = false
        let usage1 = try await base.stream(base.urlRequest(for: r, excerpt: excerpt)) { raw in
            var e = remap(raw)
            if case .completed(var res) = e {
                if let a = res.answer {
                    info.remappedPages = a.steps.flatMap(\.evidence).filter { page($0) != $0.page }.count
                    var m = a
                    m.steps = a.steps.map(remap)
                    m.branches = a.branches.map(remap)
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
        _ = try await base.stream(base.urlRequest(for: r)) { e in
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
