import Foundation
import AckshuallyCore

struct HighlightResult: Codable {
    var step: Int
    var page: Int
    var quote: String?
    var outcome: String          // matched | matched_other_page | not_matched | no_quote
    var detail: String
    var matchedPage: Int?
    var errorRate: Double?
    /// Highlight rects located on the page (0 = text matched but not located: the app shows the page).
    var rects: Int?
    /// GlyphLocator's confidence in the located geometry (0–1).
    var geometryScore: Double?
    var box: NormalizedBox?
    var boxCheck: String?
    /// IoU with expected box (if the question has one and the page matches).
    var boxIoU: Double?
    var boxCenterInExpected: Bool?
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
    let apiKey: String
    let provider: ClaudeProvider
    let judge: Judge?

    init(opts: RunOptions, apiKey: String) {
        self.opts = opts
        self.apiKey = apiKey
        provider = ClaudeProvider(config: ClaudeConfig(apiKey: apiKey, model: opts.model, effort: opts.effort, mode: opts.mode,
                                                       useSchema: opts.useSchema, useFallbacks: opts.useFallbacks, baseURL: opts.baseURL,
                                                       requestTimeout: opts.timeout))
        judge = opts.judgeModel.map { Judge(apiKey: apiKey, model: $0, baseURL: opts.baseURL) }
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
            guard let pdfURL = Paths.findPDF(for: g, questionsFile: opts.questionsFile),
                  let pdf = try? Data(contentsOf: pdfURL), let matcher = QuoteMatcher(url: pdfURL),
                  let rulebook = RulebookIndex(data: pdf) else {
                log("⚠️  \(g.name): PDF not found (\(g.pdf)) — skipping \(g.questions.count) questions")
                for q in g.questions where !done.contains(q.id) {
                    try emit(Record(id: q.id, game: g.id, question: q.question, model: opts.model, mode: opts.mode.rawValue,
                                    effort: opts.effort, position: "-", status: "skipped", error: "PDF missing: \(g.pdf)",
                                    highlights: [], expectedVerdict: q.expectedVerdict, tags: q.tags ?? []))
                }
                continue
            }
            log("📘 \(g.name): \(pdfURL.lastPathComponent), \(matcher.pageCount) pages, \(pdf.count / 1024) KB")
            var turnsByID: [String: [Turn]] = [:]   // conversation up to and including question id
            var first = true
            for q in g.questions {
                if let limit = opts.limit, count >= limit { break }
                if !opts.onlyIDs.isEmpty && !opts.onlyIDs.contains(q.id) { continue }
                if done.contains(q.id) {
                    // Resumed: rebuild conversation context from the earlier run.
                    first = false
                    if let r = records.first(where: { $0.id == q.id }) {
                        let h = q.follows.flatMap { turnsByID[$0] } ?? []
                        turnsByID[q.id] = h + [Turn(question: q.question, answer: r.answer, rawAssistantText: r.rawText ?? "")]
                    }
                    continue
                }
                count += 1
                let history = q.follows.flatMap { turnsByID[$0] } ?? []
                let position = q.follows != nil ? "followup" : (first ? "cold" : "warm")
                first = false
                log("  → \(q.id) [\(position)] \(q.question.prefix(70))")
                var rec = await ask(q: q, game: g, pdf: pdf, title: g.name, history: history, matcher: matcher, position: position,
                                    rulebook: rulebook)
                if let a = rec.answer, let judge {
                    let cited = Set(a.steps.flatMap { $0.evidence.map(\.page) } + (q.expectedPages ?? []))
                    let texts = cited.sorted().filter { $0 >= 1 && $0 <= matcher.pageCount }
                        .map { (page: $0, text: matcher.document.page(at: $0 - 1)?.string ?? "") }
                    rec.judge = await judge.judge(question: q, answer: a, pageTexts: texts)
                }
                turnsByID[q.id] = history + [Turn(question: q.question, answer: rec.answer, rawAssistantText: rec.rawText ?? "")]
                log("    \(summary(rec))")
                try emit(rec)
            }
        }
        try out.close()
        return records
    }

    private func ask(q: Question, game: GameQuestions, pdf: Data, title: String, history: [Turn],
                     matcher: QuoteMatcher, position: String, rulebook: RulebookIndex) async -> Record {
        var rec = Record(id: q.id, game: game.id, question: q.question, model: opts.model, mode: opts.mode.rawValue,
                         effort: opts.effort, position: position, status: "ok", highlights: [],
                         expectedVerdict: q.expectedVerdict, tags: q.tags ?? [])
        let start = Date()
        func t() -> Double { Date().timeIntervalSince(start) }
        let stream = provider.answer(AnswerRequest(pdf: pdf, documentTitle: title, question: q.question, history: history,
                                                   pageSelection: opts.pages, rulebook: rulebook))
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
                                    let exp = Set(q.expectedPages ?? [])
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
        if let a = rec.answer { score(&rec, q: q, answer: a, matcher: matcher) }
        return rec
    }

    private func score(_ rec: inout Record, q: Question, answer: Answer, matcher: QuoteMatcher) {
        let cited = Set(answer.steps.flatMap { $0.evidence.map(\.page) })
        if let exp = q.expectedPages, !exp.isEmpty {
            rec.evidencePageCorrect = !cited.isDisjoint(with: exp)
        }
        for (si, s) in answer.steps.enumerated() {
            for e in s.evidence {
                var h = HighlightResult(step: si, page: e.page, quote: e.quote, outcome: "no_quote", detail: "")
                if let quote = e.quote {
                    let m = matcher.match(quote: quote, page: e.page)
                    h.detail = m.label
                    switch m {
                    case .matched(let qm): h.outcome = "matched"; h.matchedPage = qm.page; h.errorRate = qm.errorRate
                    case .matchedOtherPage(let qm, _): h.outcome = "matched_other_page"; h.matchedPage = qm.page; h.errorRate = qm.errorRate
                    case .notMatched(let best, _): h.outcome = "not_matched"; h.errorRate = best
                    }
                    if let qm = m.match { h.rects = qm.rects.count; h.geometryScore = qm.geometryScore }
                }
                if let b = e.box {
                    h.box = b
                    h.boxCheck = QuoteMatcher.check(box: b).rawValue
                    if let eb = q.expectedBox, q.expectedPages?.first == e.page {
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
