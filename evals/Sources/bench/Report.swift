import Foundation
import AckshuallyCore

enum Report {
    static func load(_ url: URL) -> [Record] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var byID: [String: Record] = [:]
        var order: [String] = []
        for line in text.split(separator: "\n") {
            guard let r = try? JSONDecoder().decode(Record.self, from: Data(line.utf8)) else { continue }
            if byID[r.id] == nil { order.append(r.id) }
            byID[r.id] = r  // last write wins (resume / re-run)
        }
        return order.compactMap { byID[$0] }
    }

    static func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%d/%d (%.0f%%)", n, d, 100 * Double(n) / Double(d)) }

    static func quantile(_ xs: [Double], _ q: Double) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        return s[min(s.count - 1, Int((Double(s.count - 1) * q).rounded()))]
    }

    static func sec(_ d: Double?) -> String { d.map { String(format: "%.1f", $0) } ?? "–" }

    static func markdown(_ all: [Record], title: String, config: String) -> String {
        let asked = all.filter { $0.status != "skipped" }
        let skipped = all.filter { $0.status == "skipped" }
        let ok = asked.filter { $0.status == "ok" }
        var md = "# \(title)\n\n\(config)\n\n"
        if asked.isEmpty {
            md += "**No questions were run.** \(skipped.count) skipped"
            let reasons = Set(skipped.compactMap(\.error))
            md += reasons.isEmpty ? ".\n" : ":\n\n" + reasons.sorted().map { "- \($0)" }.joined(separator: "\n") + "\n"
            return md
        }

        // Summary
        let judged = asked.compactMap(\.judge)
        let correct = judged.filter { $0.label == "correct" }.count
        let partial = judged.filter { $0.label == "partially_correct" }.count
        let pageKnown = asked.compactMap(\.evidencePageCorrect)
        let quotes = asked.flatMap(\.highlights).filter { $0.quote != nil }
        let matched = quotes.filter { $0.outcome == "matched" }.count
        let other = quotes.filter { $0.outcome == "matched_other_page" }.count
        let qWithAllMatched = ok.filter { r in
            let q = r.highlights.filter { $0.quote != nil }
            return !q.isEmpty && q.allSatisfy { $0.outcome == "matched" }
        }.count
        let boxes = asked.flatMap(\.highlights).filter { $0.box != nil }
        let boxOK = boxes.filter { $0.boxCheck == "ok" }.count
        let boxScored = boxes.compactMap(\.boxIoU)
        let failures = asked.filter { $0.status != "ok" }
        let verdictTimes = ok.compactMap(\.tVerdict)
        let step1Times = ok.compactMap(\.tFirstStep)
        let within5 = ok.filter { ($0.tFirstStep ?? .infinity) <= 5 }.count

        md += "## Summary\n\n| Metric | Value |\n|---|---|\n"
        md += "| Questions run | \(asked.count) (skipped: \(skipped.count)) |\n"
        md += "| Failures (timeout / invalid output / API error) | \(failures.filter { $0.status == "timeout" }.count) / \(failures.filter { $0.status == "invalid_output" }.count) / \(failures.filter { $0.status == "api_error" }.count) |\n"
        md += "| Verdict correct — **LLM judge** | \(pct(correct, asked.count)) (+\(partial) partial; \(asked.count - judged.count) not judged) |\n"
        md += "| Evidence page correct (where expected pages known) | \(pct(pageKnown.filter { $0 }.count, pageKnown.count)) |\n"
        md += "| Quotes matched on claimed page | \(pct(matched, quotes.count)) (+\(other) found on another page) |\n"
        let viaFragments = quotes.filter { $0.outcome == "matched" && $0.layout == "fragments" }.count
        let partials = quotes.filter { $0.outcome == "partial" }.count
        md += "| Quotes matched through fragments (layout-tolerant) / partial | \(viaFragments) / \(partials) |\n"
        md += "| Answers with every quote matched | \(pct(qWithAllMatched, ok.count)) |\n"
        md += "| Figure boxes sane (inside page, not degenerate/whole page) | \(pct(boxOK, boxes.count)) |\n"
        if !boxScored.isEmpty {
            md += "| Figure boxes IoU ≥ 0.3 vs expected | \(pct(boxScored.filter { $0 >= 0.3 }.count, boxScored.count)) (center inside expected: \(boxes.compactMap(\.boxCenterInExpected).filter { $0 }.count)) |\n"
        }
        md += "| Verdict time median / p90 (s) | \(sec(quantile(verdictTimes, 0.5))) / \(sec(quantile(verdictTimes, 0.9))) |\n"
        md += "| Step 1 ready median / p90 (s) | \(sec(quantile(step1Times, 0.5))) / \(sec(quantile(step1Times, 0.9))) |\n"
        md += "| Step 1 within 5 s | \(pct(within5, ok.count)) |\n"
        let totalCost = asked.compactMap(\.costUSD).reduce(0, +)
        let judgeTokens = judged.map(\.usage).reduce(TokenUsage(), +)
        md += "| Total answer cost | $\(String(format: "%.3f", totalCost)) (judge extra: \(judgeTokens.inputTokens) in / \(judgeTokens.outputTokens) out tokens) |\n\n"

        // Page selection
        let rr = asked.filter { $0.retrieval != nil }
        if !rr.isEmpty {
            let ris = rr.compactMap(\.retrieval)
            let recallKnown = ris.compactMap(\.recall)
            let anyKnown = ris.compactMap(\.anyExpected)
            let excerpts = ris.filter { !$0.fullDocument }
            let fb = rr.filter { $0.retrieval?.fellBack == true }
            let discardedCost = rr.compactMap { r in r.retrieval?.discardedUsage.map { ModelPricing.cost(model: r.model, usage: $0) ?? 0 } }.reduce(0, +)
            let sentPages = ris.map { $0.fullDocument ? $0.pageCount : $0.pages.count }.reduce(0, +)
            let allPages = ris.map(\.pageCount).reduce(0, +)
            md += "## Page selection\n\n| Metric | Value |\n|---|---|\n"
            md += "| Retrieval recall: every expected page sent | \(pct(recallKnown.filter { $0 }.count, recallKnown.count)) (at least one: \(pct(anyKnown.filter { $0 }.count, anyKnown.count))) |\n"
            md += "| Pages sent (first attempt) | \(sentPages)/\(allPages) (\(allPages == 0 ? "–" : String(format: "%.0f%%", 100 * Double(sentPages) / Double(allPages)))); mean excerpt \(excerpts.isEmpty ? "–" : String(format: "%.1f", Double(excerpts.map(\.pages.count).reduce(0, +)) / Double(excerpts.count))) pages |\n"
            md += "| Full PDF chosen up front | \(pct(ris.filter(\.fullDocument).count, ris.count)) \(Set(ris.compactMap(\.reason).map { $0.replacingOccurrences(of: #"\d+/\d+"#, with: "n/N", options: .regularExpression) }).sorted().joined(separator: "; ")) |\n"
            md += "| Excerpt size (attached bytes, median) | \(excerpts.isEmpty ? "–" : String(format: "%.0f KB", (quantile(excerpts.map { Double($0.excerptBytes) }, 0.5) ?? 0) / 1024)) |\n"
            md += "| Fallback to full PDF (excerpt said not_covered) | \(pct(fb.count, rr.count)): \(fb.map(\.id).joined(separator: ", ")); fallback started at median \(sec(quantile(fb.compactMap { $0.retrieval?.fallbackAfter }, 0.5))) s; discarded attempts cost $\(String(format: "%.3f", discardedCost)) |\n"
            md += "| Evidence pages remapped (model cited an excerpt position) | \(ris.map(\.remappedPages).reduce(0, +)) |\n"
            md += "| Local prepare time (rank + build excerpt), median / max | \(String(format: "%.0f / %.0f ms", (quantile(ris.map(\.prepareSeconds), 0.5) ?? 0) * 1000, (ris.map(\.prepareSeconds).max() ?? 0) * 1000)) |\n\n"
        }

        // Latency & cost by position
        md += "## Latency by position (seconds, median / p90)\n\n"
        md += "cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context\n\n"
        md += "| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |\n|---|---|---|---|---|---|---|---|\n"
        for pos in ["cold", "warm", "followup"] {
            let rs = ok.filter { $0.position == pos }
            guard !rs.isEmpty else { continue }
            func mp(_ k: KeyPath<Record, Double?>) -> String {
                let xs = rs.compactMap { $0[keyPath: k] }
                return "\(sec(quantile(xs, 0.5))) / \(sec(quantile(xs, 0.9)))"
            }
            md += "| \(pos) | \(rs.count) | \(mp(\.tFirstToken)) | \(mp(\.tRestated)) | \(mp(\.tVerdict)) | \(mp(\.tFirstEvidence)) | \(mp(\.tFirstStep)) | \(mp(\.tTotal)) |\n"
        }
        md += "\n## Tokens & cost by position (mean per question)\n\n"
        md += "| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |\n|---|---|---|---|---|---|---|\n"
        for pos in ["cold", "warm", "followup"] {
            let rs = asked.filter { $0.position == pos && $0.usage != nil }
            guard !rs.isEmpty else { continue }
            let n = Double(rs.count)
            let u = rs.compactMap(\.usage).reduce(TokenUsage(), +)
            let c = rs.compactMap(\.costUSD).reduce(0, +)
            md += "| \(pos) | \(rs.count) | \(Int(Double(u.inputTokens) / n)) | \(Int(Double(u.cacheCreationInputTokens) / n)) | \(Int(Double(u.cacheReadInputTokens) / n)) | \(Int(Double(u.outputTokens) / n)) | $\(String(format: "%.4f", c / n)) |\n"
        }

        // Projection (test plan: total cost at 1, 5, 20 questions per PDF)
        let coldC = asked.filter { $0.position == "cold" }.compactMap(\.costUSD)
        let warmC = asked.filter { $0.position != "cold" }.compactMap(\.costUSD)
        if !coldC.isEmpty, !warmC.isEmpty {
            let c = coldC.reduce(0, +) / Double(coldC.count), w = warmC.reduce(0, +) / Double(warmC.count)
            md += "\nProjected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): "
            md += [1, 5, 20].map { "\($0) q → $\(String(format: "%.2f", c + Double($0 - 1) * w))" }.joined(separator: " · ") + "\n"
        }

        // Per question
        let sel = asked.contains { $0.retrieval != nil }
        md += "\n## Per question\n\n| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |\(sel ? " Sent | Recall |" : "")\n|---|---|---|---|---|---|---|---|---|---|\(sel ? "---|---|" : "")\n"
        for r in asked {
            let q = r.highlights.filter { $0.quote != nil }
            let m = q.filter { $0.outcome == "matched" }.count
            let boxNote = r.highlights.contains { $0.box != nil } ? " +box" : ""
            md += "| \(r.id) | \(r.position) | \(r.status) | \(r.judge?.label ?? "–") | \(r.evidencePageCorrect.map { $0 ? "✓" : "✗" } ?? "TODO") | \(m)/\(q.count)\(boxNote) | \(sec(r.tVerdict)) | \(sec(r.tFirstStep)) | \(sec(r.tTotal)) | \(r.costUSD.map { String(format: "$%.4f", $0) } ?? "–") |"
            if sel {
                let ri = r.retrieval
                let sent = ri.map { $0.fullDocument ? "full" : $0.pages.map(String.init).joined(separator: ",") } ?? "–"
                md += " \(sent)\(ri?.fellBack == true ? " → full" : "") | \(ri?.recall.map { $0 ? "✓" : "✗" } ?? "–") |"
            }
            md += "\n"
        }

        // Details worth reading
        md += "\n## Misses\n\n"
        var any = false
        for r in asked {
            var lines: [String] = []
            if r.status != "ok" { lines.append("- **\(r.status)**: \(r.error ?? "")") }
            if let j = r.judge, j.label != "correct" {
                lines.append("- judge **\(j.label)**: \(j.reason)")
                lines.append("  - expected: \(r.expectedVerdict)")
                lines.append("  - got: \(r.answer?.verdict ?? "–") (\(r.answer?.confidence.rawValue ?? "–"))")
            }
            if r.evidencePageCorrect == false {
                lines.append("- cited pages \(Set(r.highlights.map(\.page)).sorted()) don't include an expected page")
            }
            for h in r.highlights where h.quote != nil && h.outcome != "matched" {
                lines.append("- step \(h.step + 1) p.\(h.page): \(h.detail) — “\(h.quote!.prefix(120))”")
            }
            for h in r.highlights where h.box != nil && (h.boxCheck != "ok" || (h.boxIoU ?? 1) < 0.3) {
                lines.append("- box p.\(h.page) \(h.boxCheck ?? "") IoU \(h.boxIoU.map { String(format: "%.2f", $0) } ?? "n/a")")
            }
            if !lines.isEmpty {
                any = true
                md += "**\(r.id)** — \(r.question)\n" + lines.joined(separator: "\n") + "\n\n"
            }
        }
        if !any { md += "None.\n" }
        if !skipped.isEmpty {
            md += "\n## Skipped\n\n" + Set(skipped.compactMap(\.error)).sorted().map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        return md
    }
}
