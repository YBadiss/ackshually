import Foundation
import AckshuallyCore

let usage = """
usage:
  bench run [--questions FILE] [--model ID] [--mode json|citations] [--effort low|medium|high|xhigh|max]
            [--judge-model ID | --no-judge] [--game ID[,ID]] [--id QID[,QID]] [--limit N]
            [--timeout SEC] [--no-schema] [--no-fallbacks] [--out DIR] [--resume DIR] [--base-url URL]
            [--pages all|auto] [--k N] [--neighbors N] [--max-pages N] [--excerpt pdf|text]
            [--full-if-coverage X] [--min-confidence X] [--no-page-fallback]
  bench retrieve [--questions FILE] [--k N] [--neighbors N] [--explain QID,..]
                                   offline: pages page selection would send, retrieval recall
  bench report DIR                 regenerate DIR/report.md from DIR/results.jsonl
  bench fixture [PATH]             (re)generate the fake test rulebook PDF
  bench match PDF PAGE "QUOTE"     debug the quote matcher on one quote
  bench pages PDF                  print per-page text-layer status

defaults: --questions questions/m1.json --model claude-sonnet-5-5 --mode json --effort low
          --judge-model claude-sonnet-5-5 --timeout 120 --pages all   (paths relative to evals/ or repo root)
page selection (--pages auto): --k 3 --neighbors 1 --excerpt pdf --full-if-coverage 0.75, fallback to the
          full PDF when the excerpt answers not_covered (--no-page-fallback to disable)
"""

var args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(1) }
args.removeFirst()

@MainActor func flag(_ name: String) -> Bool {
    if let i = args.firstIndex(of: name) { args.remove(at: i); return true }
    return false
}
@MainActor func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let v = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return v
}

/// --k N (top pages) --neighbors N --max-pages N --full-if-coverage X --min-confidence X
/// --excerpt pdf|text --no-page-fallback
@MainActor func pageOptions() -> PageSelectionOptions {
    var o = PageSelectionOptions()
    if let v = option("--k").flatMap(Int.init) { o.topK = v }
    if let v = option("--neighbors").flatMap(Int.init) { o.neighbors = v }
    if let v = option("--max-pages").flatMap(Int.init) { o.maxPages = v }
    if let v = option("--full-if-coverage").flatMap(Double.init) { o.fullIfCoverage = v }
    if let v = option("--min-confidence").flatMap(Double.init) { o.minConfidence = v }
    if let v = option("--excerpt").flatMap(ExcerptRepresentation.init(rawValue:)) { o.representation = v }
    if flag("--no-page-fallback") { o.fallbackOnNotCovered = false }
    return o
}

let benchDir: URL = {
    // Works from evals/ or from the repo root.
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("questions").path) { return cwd }
    return cwd.appendingPathComponent("evals")
}()

func resolveLocal(_ p: String) -> URL {
    if p.hasPrefix("/") { return URL(fileURLWithPath: p) }
    let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(p)
    if FileManager.default.fileExists(atPath: cwdURL.path) { return cwdURL }
    return benchDir.appendingPathComponent(p)
}

let fixturePath = benchDir.appendingPathComponent("fixtures/fake-rulebook.pdf")

switch cmd {
case "fixture":
    let url = args.first.map(resolveLocal) ?? fixturePath
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FixtureRulebook.write(to: url)
    print("wrote \(url.path)")

case "match":
    guard args.count >= 3, let page = Int(args[1]), let m = QuoteMatcher(url: resolveLocal(args[0])) else { print(usage); exit(1) }
    let r = m.match(quote: args[2], page: page)
    print(r.label)
    if let q = r.match {
        print(String(format: "error rate %.3f, %d rect(s), geometry %@", q.errorRate, q.rects.count,
                     q.geometryScore.map { String(format: "%.2f", $0) } ?? "not located"))
        for b in q.rects { print(String(format: "  x=%.3f y=%.3f w=%.3f h=%.3f", b.x, b.y, b.w, b.h)) }
        print("text: \(q.matchedText)")
    }

case "pages":
    guard let p = args.first, let m = QuoteMatcher(url: resolveLocal(p)) else { print(usage); exit(1) }
    for i in 1...m.pageCount {
        let n = m.document.page(at: i - 1)?.string?.count ?? 0
        print("p.\(i): \(m.hasTextLayer(page: i) ? "text" : "NO TEXT LAYER") (\(n) chars)")
    }

case "retrieve":
    // Offline: which pages page selection would send for each question, and retrieval recall.
    let questions = resolveLocal(option("--questions") ?? "questions/m1.json")
    let po = pageOptions()
    let explain = Set((option("--explain") ?? "").split(separator: ",").map(String.init))
    let set = try JSONDecoder().decode(QuestionSet.self, from: Data(contentsOf: questions))
    var hit = 0, known = 0, sent = 0, total = 0, full = 0
    for g in set.games {
        guard let url = Paths.findPDF(for: g, questionsFile: questions), let rb = RulebookIndex(url: url) else { continue }
        var asked: [String: [Turn]] = [:]
        for q in g.questions {
            let history = q.follows.flatMap { asked[$0] } ?? []
            // Pin expected pages of the previous question as a stand-in for its cited pages.
            let prevPages = q.follows.flatMap { id in g.questions.first { $0.id == id }?.expectedPages } ?? []
            let hist = history.map { t in Turn(question: t.question, answer: Answer(restatedQuestion: "", verdict: "", confidence: .stated,
                steps: [Step(text: "", evidence: prevPages.map { Evidence(page: $0, quote: nil) })]), rawAssistantText: "") }
            let sel = rb.select(question: q.question, history: hist, options: po)
            asked[q.id] = history + [Turn(question: q.question, answer: nil, rawAssistantText: "")]
            let exp = q.expectedPages ?? []
            let ok = exp.isEmpty ? nil : Set(exp).isSubset(of: sel.pages)
            if let ok { known += 1; if ok { hit += 1 } }
            sent += sel.pages.count; total += rb.pageCount; if sel.isFullDocument { full += 1 }
            let kb = sel.isFullDocument ? 0 : (rb.excerptPDF(sel)?.count ?? 0) / 1024
            let top = sel.ranked.prefix(5).map(String.init).joined(separator: ",")
            print("\(q.id.padding(toLength: 6, withPad: " ", startingAt: 0)) \(ok.map { $0 ? "✓" : "✗" } ?? "·") exp=\(exp) "
                  + "sent=\(sel.isFullDocument ? "FULL(\(sel.reason ?? ""))" : "\(sel.pages)") conf=\(String(format: "%.2f", sel.confidence)) top=[\(top)] \(kb)KB")
            if explain.contains(q.id) {
                let qt = PageIndex.queryTerms(question: q.question, history: history.map(\.question))
                print("   query: " + qt.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " "))
                for p in Array(sel.ranked.prefix(4)) + exp where p <= rb.pageCount {
                    print("   p.\(p): " + rb.index.explain(qt, page: p).prefix(8).map { "\($0.term) \(String(format: "%.2f", $0.score))" }.joined(separator: ", "))
                }
            }
        }
    }
    print("recall \(hit)/\(known), pages sent \(sent)/\(total) (\(String(format: "%.0f", 100 * Double(sent) / Double(max(total, 1))))%), full PDF \(full)")

case "report":
    guard let d = args.first else { print(usage); exit(1) }
    let dir = resolveLocal(d)
    let recs = Report.load(dir.appendingPathComponent("results.jsonl"))
    let cfg = (try? String(contentsOf: dir.appendingPathComponent("config.txt"), encoding: .utf8)) ?? ""
    try Report.markdown(recs, title: "Bench report", config: cfg).write(to: dir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
    print(dir.appendingPathComponent("report.md").path)

case "run":
    let questions = resolveLocal(option("--questions") ?? "questions/m1.json")
    let model = option("--model") ?? "claude-sonnet-5-5"
    let modeS = option("--mode") ?? "json"
    guard let mode = EvidenceMode(rawValue: modeS) else { print("bad --mode \(modeS)"); exit(1) }
    let effort = option("--effort") ?? "low"
    let noJudge = flag("--no-judge")
    let judgeModel = option("--judge-model") ?? "claude-sonnet-5-5"
    let timeout = Double(option("--timeout") ?? "120") ?? 120
    let games = Set((option("--game") ?? "").split(separator: ",").map(String.init))
    let ids = Set((option("--id") ?? "").split(separator: ",").map(String.init))
    let limit = option("--limit").flatMap(Int.init)
    let noSchema = flag("--no-schema")
    let noFallbacks = flag("--no-fallbacks")
    let resumeDir = option("--resume")
    let baseURL = URL(string: option("--base-url") ?? "https://api.anthropic.com")!
    let pagesArg = option("--pages") ?? "all"
    let pageOpts = pageOptions()
    guard ["all", "auto"].contains(pagesArg) else { print("bad --pages \(pagesArg)"); exit(1) }
    let pageMode: PageSelectionMode = pagesArg == "auto" ? .automatic(pageOpts) : .fullDocument
    let pagesTag = pagesArg == "auto"
        ? "-k\(pageOpts.topK)n\(pageOpts.neighbors)\(pageOpts.maxPages.map { "max\($0)" } ?? "")-\(pageOpts.representation.rawValue)\(pageOpts.fallbackOnNotCovered ? "" : "-nofb")"
        : ""
    let stamp: String = {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
    }()
    let outDir = resumeDir.map(resolveLocal)
        ?? option("--out").map(resolveLocal)
        ?? benchDir.appendingPathComponent("out/\(stamp)-\(model)-\(mode.rawValue)-\(effort)\(pagesTag)")
    if !args.isEmpty { print("unknown arguments: \(args)\n\n\(usage)"); exit(1) }

    if !FileManager.default.fileExists(atPath: fixturePath.path) {
        try FileManager.default.createDirectory(at: fixturePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FixtureRulebook.write(to: fixturePath)
    }
    guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
        log("⏸  ANTHROPIC_API_KEY is not set — nothing was sent. Export it and re-run the same command.")
        exit(2)
    }
    let config = """
    - Date: \(Date())
    - Questions: `\(questions.lastPathComponent)`
    - Model: `\(model)` · effort `\(effort)` · evidence mode `\(mode.rawValue)`\(mode == .json ? (noSchema ? " (prompt-only JSON)" : " (structured outputs)") : "")
    - Verdict correctness is graded by an **LLM judge** (`\(noJudge ? "disabled" : judgeModel)`), not by a human.
    - Pages sent: \(pagesArg == "auto" ? "**page selection** — top \(pageOpts.topK) BM25 pages + \(pageOpts.neighbors) neighbour(s)\(pageOpts.maxPages.map { ", max \($0)" } ?? ""), as \(pageOpts.representation.rawValue), full PDF if ≥\(Int(pageOpts.fullIfCoverage * 100))% of pages\(pageOpts.minConfidence > 0 ? " or confidence < \(pageOpts.minConfidence)" : ""), \(pageOpts.fallbackOnNotCovered ? "re-ask with full PDF on not_covered" : "no fallback")" : "full PDF")
    """
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    try config.write(to: outDir.appendingPathComponent("config.txt"), atomically: true, encoding: .utf8)
    let opts = RunOptions(questionsFile: questions, outDir: outDir, model: model, mode: mode, effort: effort,
                          useSchema: !noSchema, useFallbacks: !noFallbacks, judgeModel: noJudge ? nil : judgeModel,
                          timeout: timeout, baseURL: baseURL, onlyGames: games, onlyIDs: ids, limit: limit, resume: resumeDir != nil,
                          pages: pageMode)
    let records = try await Runner(opts: opts, apiKey: key).run()
    let md = Report.markdown(records, title: "Bench report — \(model) / \(mode.rawValue) / effort \(effort)", config: config)
    try md.write(to: outDir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
    print(outDir.appendingPathComponent("report.md").path)

default:
    print(usage)
    exit(1)
}
