import Foundation
import PDFKit
import AckshuallyCore

struct HighlightResult: Codable {
    var step: Int
    var page: Int
    /// Several-book games: the cited page in its own book ("Riverfolk p.4").
    var reference: String?
    var quote: String?
    var outcome: String          // matched | matched_other_page | partial | not_matched | no_quote
    var detail: String
    var matchedPage: Int?
    var errorRate: Double?
    /// Highlight rects located on the page (0 = text matched but not located: the app shows the page).
    var rects: Int?
    /// GlyphLocator's confidence in the located geometry (0–1).
    var geometryScore: Double?
    /// continuous | fragments | partial (nil in runs before layout-tolerant matching).
    var layout: String?
    /// Share of the quote found (fragments / partial).
    var coverage: Double?
    var fragments: Int?
    var box: NormalizedBox?
    var boxCheck: String?
    /// IoU with expected box (if the question has one and the page matches).
    var boxIoU: Double?
    var boxCenterInExpected: Bool?
}

extension HighlightResult {
    /// Records a matcher outcome (also used by `bench rescore`).
    mutating func apply(_ m: MatchOutcome) {
        detail = m.label
        switch m {
        case .matched(let qm): outcome = qm.layout == .partial ? "partial" : "matched"; matchedPage = qm.page; errorRate = qm.errorRate
        case .matchedOtherPage(let qm, _): outcome = "matched_other_page"; matchedPage = qm.page; errorRate = qm.errorRate
        case .notMatched(let best, _): outcome = "not_matched"; errorRate = best; matchedPage = nil
        }
        rects = m.match?.rects.count
        geometryScore = m.match?.geometryScore
        layout = m.match?.layout.rawValue
        coverage = m.match?.coverage
        fragments = m.match.map { $0.fragments.count }
    }
}

/// Page selection outcome for one question (nil when the run sent full PDFs).
struct RetrievalRecord: Codable {
    var pages: [Int]               // pages sent on the first attempt (original numbers)
    var pageCount: Int
    var fullDocument: Bool         // retrieval gave up and sent the whole PDF
    var reason: String?
    var confidence: Double
    var ranked: [Int]              // top-ranked pages, best first
    /// All expected pages were sent (nil = expected pages unknown).
    var recall: Bool?
    /// At least one expected page was sent.
    var anyExpected: Bool?
    var representation: String
    var excerptBytes: Int
    var prepareSeconds: Double
    var fellBack: Bool
    var fallbackAfter: Double?
    var discardedUsage: TokenUsage?
    var remappedPages: Int
}

struct Judgement: Codable {
    var label: String   // correct | partially_correct | incorrect
    var reason: String
    var model: String
    var usage: TokenUsage
}

struct Record: Codable {
    var id: String
    var game: String
    var question: String
    var model: String
    var mode: String
    var effort: String
    /// cold = first request on this PDF (cache write); warm = later new question; followup = in a chain.
    var position: String
    var status: String          // ok | invalid_output | timeout | api_error | skipped
    var error: String?
    var tFirstToken: Double?
    var tRestated: Double?
    var tVerdict: Double?
    var tFirstEvidence: Double?
    var tFirstStep: Double?
    var tTotal: Double?
    var usage: TokenUsage?
    var costUSD: Double?
    var answer: Answer?
    var rawText: String?
    var judge: Judgement?
    /// nil = expected pages TODO.
    var evidencePageCorrect: Bool?
    var highlights: [HighlightResult]
    var expectedVerdict: String
    var tags: [String]
    var retrieval: RetrievalRecord?
    /// Several-book games: titles of the books sent (core + ticked add-ons), and the sent PDF's size.
    var books: [String]?
    var documentBytes: Int?
}

/// What one question sends: a game's books in play joined (one book: its PDF unchanged), with a matcher and
/// a page index on the same bytes.
struct SentDocument {
    var key: String
    var books: [BookSpec]
    var joined: JoinedRulebook
    var matcher: QuoteMatcher
    var rulebook: RulebookIndex

    /// `expected_pages` (pages of a one-PDF game) or `expected_book_pages` mapped to pages of this document;
    /// pages of books not sent are dropped.
    func expectedPages(_ q: Question) -> [Int] {
        if let bp = q.expectedBookPages {
            return bp.compactMap { p in
                books.first { $0.id == p.book }.flatMap { joined.contents.documentPage(book: $0.title, page: p.page) }
            }
        }
        return q.expectedPages ?? []
    }
}

struct RunOptions {
    var questionsFile: URL
    var outDir: URL
    var model: String
    var mode: EvidenceMode
    var effort: String
    var useSchema: Bool
    var useFallbacks: Bool
    var judgeModel: String?
    var timeout: Double
    var baseURL: URL
    var onlyGames: Set<String>
    var onlyIDs: Set<String>
    var limit: Int?
    var resume: Bool
    var pages: PageSelectionMode = .fullDocument
}

struct TimeoutError: Error {}

final class Runner {
    let opts: RunOptions
    /// Claude, plus page selection when `--pages auto` asks for it (`.fullDocument` passes straight through).
    let provider: PageSelectingProvider
    let judge: Judge?

    init(opts: RunOptions, credential: Credential, judgeAPIKey: String) {
        self.opts = opts
        provider = PageSelectingProvider(base: ClaudeProvider(config: ClaudeConfig(
            credential: credential, model: opts.model, effort: opts.effort, mode: opts.mode, useSchema: opts.useSchema,
            useFallbacks: opts.useFallbacks, baseURL: opts.baseURL, requestTimeout: opts.timeout)))
        // Through the server, the judge's request isn't one the server accepts: send it straight to Anthropic.
        let judgeURL = credential == .apiKey(judgeAPIKey) ? opts.baseURL : URL(string: "https://api.anthropic.com")!
        judge = opts.judgeModel.map { Judge(apiKey: judgeAPIKey, model: $0, baseURL: judgeURL) }
    }

    func run() async throws -> [Record] {
        let set = try JSONDecoder().decode(QuestionSet.self, from: Data(contentsOf: opts.questionsFile))
        try FileManager.default.createDirectory(at: opts.outDir, withIntermediateDirectories: true)
        let jsonl = opts.outDir.appendingPathComponent("results.jsonl")
        var records: [Record] = opts.resume ? Report.load(jsonl) : []
        let done = Set(records.filter { $0.status != "skipped" }.map(\.id))
        if !FileManager.default.fileExists(atPath: jsonl.path) { FileManager.default.createFile(atPath: jsonl.path, contents: nil) }
        let out = try FileHandle(forWritingTo: jsonl)
        try out.seekToEnd()
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        func emit(_ r: Record) throws {
            records.removeAll { $0.id == r.id }
            records.append(r)
            try out.write(contentsOf: enc.encode(r) + Data("\n".utf8))
        }

        var count = 0
        for g in set.games where opts.onlyGames.isEmpty || opts.onlyGames.contains(g.id) {
            let specs = g.bookSpecs
            var sources: [String: (spec: BookSpec, data: Data, url: URL)] = [:]
            for b in specs {
                if let u = Paths.findPDF(for: b, questionsFile: opts.questionsFile), let d = try? Data(contentsOf: u) {
                    sources[b.id] = (b, d, u)
                }
            }
            let missing = specs.filter { sources[$0.id] == nil }
            guard missing.isEmpty else {
                let paths = missing.map(\.pdf).joined(separator: ", ")
                log("⚠️  \(g.name): PDF not found (\(paths)) — skipping \(g.questions.count) questions")
                for q in g.questions where !done.contains(q.id) {
                    try emit(Record(id: q.id, game: g.id, question: q.question, model: opts.model, mode: opts.mode.rawValue,
                                    effort: opts.effort, position: "-", status: "skipped", error: "PDF missing: \(paths)",
                                    highlights: [], expectedVerdict: q.expectedVerdict, tags: q.tags ?? []))
                }
                continue
            }
            // One sent document per set of ticked add-ons (core books always), joined once and reused, so
            // later questions on the same set read it from the prompt cache like the app does.
            var documents: [String: SentDocument] = [:]
            func document(for q: Question) -> SentDocument? {
                let ticked = Set(q.addOns ?? [])
                let key = ticked.sorted().joined(separator: "+")
                if let d = documents[key] { return d }
                let inPlay = specs.filter { $0.role == .core || ticked.contains($0.id) }
                let notInPlay = specs.filter { $0.role == .addOn && !ticked.contains($0.id) }.map(\.title)
                let started = Date()
                guard let joined = RulebookJoiner.join(inPlay.map { RulebookSource(title: $0.title, role: $0.role, pdf: sources[$0.id]!.data) },
                                                       gameTitle: g.name, notInPlay: notInPlay),
                      let matcherDoc = PDFDocument(data: joined.pdf), let rulebook = RulebookIndex(data: joined.pdf) else { return nil }
                let d = SentDocument(key: key, books: inPlay, joined: joined, matcher: QuoteMatcher(document: matcherDoc), rulebook: rulebook)
                log("📘 \(g.name) [\(inPlay.map(\.title).joined(separator: " + "))]: \(matcherDoc.pageCount) pages, "
                    + "\(joined.pdf.count / 1024) KB\(inPlay.count > 1 ? String(format: ", joined in %.1f s", Date().timeIntervalSince(started)) : "")"
                    + (AnswerRequest(books: joined, question: "").isOversize ? " (over \(ClaudeProvider.maxDocumentBytes / 1_000_000) MB: page selection)" : ""))
                documents[key] = d
                return d
            }
            var turnsByID: [String: [Turn]] = [:]   // conversation up to and including question id
            var seen: Set<String> = []              // documents already asked about (cold vs warm)
            for q in g.questions {
                if let limit = opts.limit, count >= limit { break }
                if !opts.onlyIDs.isEmpty && !opts.onlyIDs.contains(q.id) { continue }
                let key = Set(q.addOns ?? []).sorted().joined(separator: "+")
                if done.contains(q.id) {
                    // Resumed: rebuild conversation context from the earlier run.
                    seen.insert(key)
                    if let r = records.first(where: { $0.id == q.id }) {
                        let h = q.follows.flatMap { turnsByID[$0] } ?? []
                        turnsByID[q.id] = h + [Turn(question: q.question, answer: r.answer, rawAssistantText: r.rawText ?? "")]
                    }
                    continue
                }
                guard let doc = document(for: q) else {
                    log("⚠️  \(q.id): couldn't build the document"); continue
                }
                count += 1
                let history = q.follows.flatMap { turnsByID[$0] } ?? []
                let position = q.follows != nil ? "followup" : (seen.contains(key) ? "warm" : "cold")
                seen.insert(key)
                log("  → \(q.id) [\(position)] \(q.question.prefix(70))")
                var rec = await ask(q: q, game: g, doc: doc, history: history, position: position)
                if let a = rec.answer, let judge {
                    let cited = Set(a.steps.flatMap { $0.evidence.map(\.page) } + doc.expectedPages(q))
                    let c = doc.joined.contents
                    let texts = cited.sorted().filter { $0 >= 1 && $0 <= doc.matcher.pageCount }
                        .map { p in (page: p, label: c.isJoined ? "page \(p) (\(c.reference(for: p).label))" : "page \(p)",
                                     text: doc.matcher.document.page(at: p - 1)?.string ?? "") }
                    rec.judge = await judge.judge(question: q, answer: a, pageTexts: texts,
                                                  books: doc.books.map(\.title), notInPlay: c.notInPlay)
                }
                turnsByID[q.id] = history + [Turn(question: q.question, answer: rec.answer, rawAssistantText: rec.rawText ?? "")]
                log("    \(summary(rec))")
                try emit(rec)
            }
        }
        try out.close()
        return records
    }

    private func ask(q: Question, game: GameQuestions, doc: SentDocument, history: [Turn], position: String) async -> Record {
        var rec = Record(id: q.id, game: game.id, question: q.question, model: opts.model, mode: opts.mode.rawValue,
                         effort: opts.effort, position: position, status: "ok", highlights: [],
                         expectedVerdict: q.expectedVerdict, tags: q.tags ?? [])
        if game.books != nil {
            rec.books = doc.books.map(\.title)
            rec.documentBytes = doc.joined.pdf.count
        }
        let matcher = doc.matcher
        let expectedPages = doc.expectedPages(q)
        let start = Date()
        func t() -> Double { Date().timeIntervalSince(start) }
        let stream = provider.answer(AnswerRequest(books: doc.joined, question: q.question, history: history,
                                                   pageSelection: opts.pages, rulebook: doc.rulebook))
        let timeout = opts.timeout
        let box = RecordBox(rec)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for try await e in stream {
                        switch e {
                        case .firstToken: box.update { $0.tFirstToken = $0.tFirstToken ?? t() }
                        case .restatedQuestion: box.update { $0.tRestated = $0.tRestated ?? t() }
                        case .verdict: box.update { $0.tVerdict = $0.tVerdict ?? t() }
                        case .evidence(let s, _, _) where s == 0: box.update { $0.tFirstEvidence = $0.tFirstEvidence ?? t() }
                        case .step(let i, _) where i == 0: box.update { $0.tFirstStep = $0.tFirstStep ?? t() }
                        case .completed(let r):
                            box.update {
                                $0.tTotal = t()
                                $0.usage = r.usage
                                $0.model = r.model
                                $0.costUSD = ModelPricing.cost(model: r.model, usage: r.usage)
                                $0.answer = r.answer
                                $0.rawText = r.rawText
                                if r.answer == nil { $0.status = "invalid_output" }
                                if let ri = r.retrieval {
                                    let exp = Set(expectedPages)
                                    let sent = Set(ri.selection.pages)
                                    $0.retrieval = RetrievalRecord(
                                        pages: ri.selection.pages, pageCount: ri.selection.pageCount,
                                        fullDocument: ri.selection.isFullDocument, reason: ri.selection.reason,
                                        confidence: ri.selection.confidence, ranked: Array(ri.selection.ranked.prefix(8)),
                                        recall: exp.isEmpty ? nil : exp.isSubset(of: sent),
                                        anyExpected: exp.isEmpty ? nil : !exp.isDisjoint(with: sent),
                                        representation: ri.representation.rawValue, excerptBytes: ri.excerptBytes,
                                        prepareSeconds: ri.prepareSeconds, fellBack: ri.fellBackToFullDocument,
                                        fallbackAfter: ri.fallbackAfterSeconds, discardedUsage: ri.discardedUsage,
                                        remappedPages: ri.remappedPages)
                                }
                                $0.error = r.parseError
                            }
                        default: break
                        }
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw TimeoutError()
                }
                try await group.next()
                group.cancelAll()
            }
        } catch is TimeoutError {
            box.update { $0.status = "timeout"; $0.error = "no complete answer within \(Int(timeout))s" }
        } catch {
            box.update { $0.status = "api_error"; $0.error = "\(error)" }
        }
        rec = box.value
        if rec.tTotal == nil && rec.status == "ok" { rec.status = "invalid_output"; rec.error = rec.error ?? "stream ended without answer" }
        if let a = rec.answer { score(&rec, q: q, answer: a, doc: doc) }
        return rec
    }

    private func score(_ rec: inout Record, q: Question, answer: Answer, doc: SentDocument) {
        let matcher = doc.matcher
        let cited = Set(answer.steps.flatMap { $0.evidence.map(\.page) })
        let exp = doc.expectedPages(q)
        if !exp.isEmpty {
            rec.evidencePageCorrect = !cited.isDisjoint(with: exp)
        }
        for (si, s) in answer.steps.enumerated() {
            for e in s.evidence {
                var h = HighlightResult(step: si, page: e.page, quote: e.quote, outcome: "no_quote", detail: "")
                if doc.joined.contents.isJoined { h.reference = doc.joined.contents.reference(for: e.page).label }
                if let quote = e.quote {
                    h.apply(matcher.match(quote: quote, page: e.page))
                }
                if let b = e.box {
                    h.box = b
                    h.boxCheck = QuoteMatcher.check(box: b).rawValue
                    if let eb = q.expectedBox, exp.first == e.page {
                        h.boxIoU = b.iou(eb)
                        let c = b.center
                        h.boxCenterInExpected = eb.contains(x: c.0, y: c.1)
                    }
                }
                rec.highlights.append(h)
            }
        }
    }

    private func summary(_ r: Record) -> String {
        func f(_ d: Double?) -> String { d.map { String(format: "%.1fs", $0) } ?? "–" }
        let hl = r.highlights.filter { $0.quote != nil }
        let ok = hl.filter { $0.outcome == "matched" }.count
        return "\(r.status) verdict@\(f(r.tVerdict)) step1@\(f(r.tFirstStep)) total@\(f(r.tTotal)) "
            + "judge=\(r.judge?.label ?? "–") pages=\(r.evidencePageCorrect.map { $0 ? "✓" : "✗" } ?? "TODO") "
            + "highlights \(ok)/\(hl.count) cost=\(r.costUSD.map { String(format: "$%.4f", $0) } ?? "–")"
            + (r.retrieval.map { ri in
                " sent=" + (ri.fullDocument ? "FULL" : "\(ri.pages)") + (ri.recall.map { $0 ? "✓" : "✗" } ?? "")
                    + (ri.fellBack ? " FALLBACK@\(f(ri.fallbackAfter))" : "")
            } ?? "")
            + (r.error.map { " err=\($0.prefix(160))" } ?? "")
    }
}

/// Mutable record shared with the streaming task.
final class RecordBox: @unchecked Sendable {
    private var rec: Record
    private let lock = NSLock()
    init(_ r: Record) { rec = r }
    func update(_ f: (inout Record) -> Void) { lock.lock(); f(&rec); lock.unlock() }
    var value: Record { lock.lock(); defer { lock.unlock() }; return rec }
}

func log(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}
