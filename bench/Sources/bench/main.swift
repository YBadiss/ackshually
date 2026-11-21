import Foundation
import AckshuallyCore

let usage = """
usage:
  bench run [--questions FILE] [--model ID] [--mode json|citations] [--effort low|medium|high|xhigh|max]
            [--judge-model ID | --no-judge] [--game ID[,ID]] [--id QID[,QID]] [--limit N]
            [--timeout SEC] [--no-schema] [--no-fallbacks] [--out DIR] [--resume DIR] [--base-url URL]
  bench report DIR                 regenerate DIR/report.md from DIR/results.jsonl
  bench fixture [PATH]             (re)generate the fake test rulebook PDF
  bench match PDF PAGE "QUOTE"     debug the quote matcher on one quote
  bench pages PDF                  print per-page text-layer status

defaults: --questions questions/m1.json --model claude-opus-5-5 --mode json --effort low
          --judge-model claude-sonnet-5-5 --timeout 120   (paths relative to bench/ or repo root)
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

let benchDir: URL = {
    // Works from bench/ or from the repo root.
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("questions").path) { return cwd }
    return cwd.appendingPathComponent("bench")
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
        print(String(format: "error rate %.3f, %d rect(s)", q.errorRate, q.rects.count))
        for b in q.rects { print(String(format: "  x=%.3f y=%.3f w=%.3f h=%.3f", b.x, b.y, b.w, b.h)) }
        print("text: \(q.matchedText)")
    }

case "pages":
    guard let p = args.first, let m = QuoteMatcher(url: resolveLocal(p)) else { print(usage); exit(1) }
    for i in 1...m.pageCount {
        let n = m.document.page(at: i - 1)?.string?.count ?? 0
        print("p.\(i): \(m.hasTextLayer(page: i) ? "text" : "NO TEXT LAYER") (\(n) chars)")
    }

case "report":
    guard let d = args.first else { print(usage); exit(1) }
    let dir = resolveLocal(d)
    let recs = Report.load(dir.appendingPathComponent("results.jsonl"))
    let cfg = (try? String(contentsOf: dir.appendingPathComponent("config.txt"), encoding: .utf8)) ?? ""
    try Report.markdown(recs, title: "Bench report", config: cfg).write(to: dir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
    print(dir.appendingPathComponent("report.md").path)

case "run":
    let questions = resolveLocal(option("--questions") ?? "questions/m1.json")
    let model = option("--model") ?? "claude-opus-5-5"
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
    let stamp: String = {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
    }()
    let outDir = resumeDir.map(resolveLocal)
        ?? option("--out").map(resolveLocal)
        ?? benchDir.appendingPathComponent("out/\(stamp)-\(model)-\(mode.rawValue)-\(effort)")
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
    """
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    try config.write(to: outDir.appendingPathComponent("config.txt"), atomically: true, encoding: .utf8)
    let opts = RunOptions(questionsFile: questions, outDir: outDir, model: model, mode: mode, effort: effort,
                          useSchema: !noSchema, useFallbacks: !noFallbacks, judgeModel: noJudge ? nil : judgeModel,
                          timeout: timeout, baseURL: baseURL, onlyGames: games, onlyIDs: ids, limit: limit, resume: resumeDir != nil)
    let records = try await Runner(opts: opts, apiKey: key).run()
    let md = Report.markdown(records, title: "Bench report — \(model) / \(mode.rawValue) / effort \(effort)", config: config)
    try md.write(to: outDir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
    print(outDir.appendingPathComponent("report.md").path)

default:
    print(usage)
    exit(1)
}
