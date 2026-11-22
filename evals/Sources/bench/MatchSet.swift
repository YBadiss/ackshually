import Foundation
import AckshuallyCore
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// `bench match-set FILE`: a question-free regression set for the quote matcher on the real
/// rulebooks. Each entry is a short quote the model wrote (or a previous run failed to match) with
/// the outcome we expect. Games whose PDF isn't present are skipped (the PDFs are git-ignored).
struct MatchSet: Codable {
    var description: String?
    /// Game id → PDF path (relative to the repo root).
    var pdfs: [String: String]
    var quotes: [Entry]

    struct Entry: Codable {
        var game: String
        var page: Int
        var quote: String
        /// continuous | fragments | partial | other_page | not_matched
        var expect: String
        /// When set: whether the highlight must have rects (false = matched, position not located).
        var located: Bool?
        var note: String?
    }
}

enum MatchTools {
    /// "continuous" / "fragments" / "partial" / "other_page" / "not_matched".
    static func kind(_ m: MatchOutcome) -> String {
        switch m {
        case .matched(let q): return q.layout.rawValue
        case .matchedOtherPage: return "other_page"
        case .notMatched: return "not_matched"
        }
    }

    /// Runs the set; returns the number of entries whose outcome differs from `expect`.
    static func runSet(_ url: URL, renderDir: URL?) throws -> Int {
        let set = try JSONDecoder().decode(MatchSet.self, from: Data(contentsOf: url))
        let root = Paths.repoRoot(from: url) ?? url.deletingLastPathComponent()
        var matchers: [String: QuoteMatcher] = [:]
        var failures = 0, run = 0, skipped = Set<String>()
        if let renderDir { try FileManager.default.createDirectory(at: renderDir, withIntermediateDirectories: true) }
        print("| # | Game | p. | Expect | Got | Detail | Quote |\n|---|---|---|---|---|---|---|")
        for (i, e) in set.quotes.enumerated() {
            guard let rel = set.pdfs[e.game] else { print("unknown game \(e.game)"); failures += 1; continue }
            let pdf = root.appendingPathComponent(rel)
            if matchers[e.game] == nil, FileManager.default.fileExists(atPath: pdf.path) { matchers[e.game] = QuoteMatcher(url: pdf) }
            guard let m = matchers[e.game] else { skipped.insert(e.game); continue }
            run += 1
            let outcome = m.match(quote: e.quote, page: e.page)
            let hasRects = !(outcome.match?.rects.isEmpty ?? true)
            let got = kind(outcome) + (outcome.match != nil && !hasRects ? ", not located" : "")
            let ok = kind(outcome) == e.expect && (e.located == nil || e.located == hasRects)
            if !ok { failures += 1 }
            let short = e.quote.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            print("| \(i + 1) | \(e.game) | \(e.page) | \(e.expect) | \(ok ? "" : "✗ ")\(got) | \(outcome.label) | “\(short.prefix(70))\(short.count > 70 ? "…" : "")” |")
            if let renderDir, let q = outcome.match, !q.rects.isEmpty, let page = m.document.page(at: q.page - 1) {
                let out = renderDir.appendingPathComponent(String(format: "%02d-%@-p%d.png", i + 1, e.game, q.page))
                try render(page, boxes: q.rects, to: out, crop: true)
            }
        }
        print("\n\(run - failures)/\(run) as expected"
              + (skipped.isEmpty ? "" : " · skipped (PDF not present): \(skipped.sorted().joined(separator: ", "))"))
        return failures
    }

    /// Page image with the highlight rects outlined (for hand-checking placements; not committed).
    /// `crop`: only the area around the rects (plus a margin), enough to read the highlighted words.
    static func render(_ page: PDFPage, boxes: [NormalizedBox], to url: URL, scale: CGFloat = 2, crop: Bool = false) throws {
        let b = page.bounds(for: .cropBox)
        let w = Int(b.width * scale), h = Int(b.height * scale)
        var cropRect: CGRect?
        if crop, let first = boxes.first {
            let u = boxes.dropFirst().reduce(CGRect(x: first.x, y: first.y, width: first.w, height: first.h)) {
                $0.union(CGRect(x: $1.x, y: $1.y, width: $1.w, height: $1.h))
            }
            let r = u.insetBy(dx: -0.06, dy: -0.04).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            // Image space is bottom-left (CGImage cropping uses top-left rows).
            cropRect = CGRect(x: r.minX * Double(w), y: r.minY * Double(h), width: r.width * Double(w), height: r.height * Double(h))
        }
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: ctx)
        ctx.restoreGState()
        ctx.setStrokeColor(CGColor(red: 0.9, green: 0, blue: 0.4, alpha: 1))
        ctx.setFillColor(CGColor(red: 1, green: 0.9, blue: 0, alpha: 0.3))
        ctx.setLineWidth(2)
        for n in boxes {
            let r = CGRect(x: n.x * Double(w), y: (1 - n.y - n.h) * Double(h), width: n.w * Double(w), height: n.h * Double(h)).insetBy(dx: -2, dy: -2)
            ctx.fill(r)
            ctx.stroke(r)
        }
        guard let full = ctx.makeImage(), let img = cropRect.map({ full.cropping(to: $0) }) ?? full,
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }

    /// `bench rescore DIR`: re-matches every recorded quote with the current matcher (no API calls)
    /// and writes `results.jsonl` + `report.md` to `out`, plus `rescore.md` listing every quote whose
    /// outcome changed. `renderDir`: page images for each changed quote that now has rects.
    static func rescore(_ dir: URL, questions: URL, out: URL, renderDir: URL?, continuousOnly: Bool = false) throws {
        let set = try JSONDecoder().decode(QuestionSet.self, from: Data(contentsOf: questions))
        var matchers: [String: QuoteMatcher] = [:]
        for g in set.games {
            if let url = Paths.findPDF(for: g, questionsFile: questions), let m = QuoteMatcher(url: url) {
                m.layoutTolerant = !continuousOnly
                matchers[g.id] = m
            }
        }
        var records = Report.load(dir.appendingPathComponent("results.jsonl"))
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        if let renderDir { try FileManager.default.createDirectory(at: renderDir, withIntermediateDirectories: true) }
        var changes = "| Q | Step | p. | Before | After | Quote |\n|---|---|---|---|---|---|\n"
        var n = 0
        for ri in records.indices {
            guard let m = matchers[records[ri].game] else { continue }
            for hi in records[ri].highlights.indices {
                var h = records[ri].highlights[hi]
                guard let quote = h.quote else { continue }
                let before = h.outcome + (h.layout.map { $0 == "continuous" ? "" : " (\($0))" } ?? "")
                let outcome = m.match(quote: quote, page: h.page)
                h.apply(outcome)
                let after = h.outcome + (h.layout.map { $0 == "continuous" ? "" : " (\($0))" } ?? "")
                records[ri].highlights[hi] = h
                guard before != after else { continue }
                n += 1
                let short = quote.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
                changes += "| \(records[ri].id) | \(h.step + 1) | \(h.page) | \(before) | \(outcome.label) | “\(short.prefix(80))\(short.count > 80 ? "…" : "")” |\n"
                if let renderDir, let q = outcome.match, !q.rects.isEmpty, let page = m.document.page(at: q.page - 1) {
                    try render(page, boxes: q.rects, to: renderDir.appendingPathComponent("\(records[ri].id)-s\(h.step + 1)-p\(q.page)-\(hi).png"))
                }
            }
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let jsonl = try records.map { String(decoding: try enc.encode($0), as: UTF8.self) }.joined(separator: "\n") + "\n"
        try jsonl.write(to: out.appendingPathComponent("results.jsonl"), atomically: true, encoding: .utf8)
        var cfg = (try? String(contentsOf: dir.appendingPathComponent("config.txt"), encoding: .utf8)) ?? ""
        cfg += "\n- **Re-scored offline** with the current quote matcher\(continuousOnly ? ", continuous matching only (baseline)" : "") (`bench rescore`, \(Date())): same answers, new match results."
        try cfg.write(to: out.appendingPathComponent("config.txt"), atomically: true, encoding: .utf8)
        try Report.markdown(records, title: "Bench report (re-scored)", config: cfg)
            .write(to: out.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        try ("# Quotes whose match changed\n\nSource run: `\(dir.lastPathComponent)` · \(n) change(s)\n\n" + (n == 0 ? "None.\n" : changes))
            .write(to: out.appendingPathComponent("rescore.md"), atomically: true, encoding: .utf8)
        print("\(dir.lastPathComponent): \(n) quote(s) changed → \(out.path)")
    }
}
