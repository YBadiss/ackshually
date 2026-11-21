import Foundation
import PDFKit
import CoreGraphics

/// Text of one page, normalized for matching, with a map back to the original string.
/// Normalization: NFKD compatibility (ligatures ﬁ→fi), case/diacritic folding, then keep only
/// letters and digits. Whitespace, line breaks, hyphenation and punctuation all vanish, so
/// "dis-\ncard all  unused" matches "discard all unused".
public struct NormalizedText: Sendable {
    public let original: String
    /// Normalized characters as unicode scalar values (fast comparison).
    public let chars: [UInt32]
    /// UTF-16 range in `original` for each normalized char.
    public let origin: [NSRange]

    public init(_ s: String) {
        original = s
        var chars: [UInt32] = []
        var origin: [NSRange] = []
        var offset = 0
        for scalar in s.unicodeScalars {
            let len = scalar.utf16.count
            let folded = String(scalar).decomposedStringWithCompatibilityMapping
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            for c in folded.unicodeScalars where c.properties.isAlphabetic || c.properties.numericType != nil {
                chars.append(c.value)
                origin.append(NSRange(location: offset, length: len))
            }
            offset += len
        }
        self.chars = chars
        self.origin = origin
    }

    public func originalRange(_ r: Range<Int>) -> NSRange {
        let a = origin[r.lowerBound], b = origin[r.upperBound - 1]
        return NSRange(location: a.location, length: b.location + b.length - a.location)
    }
}

public struct QuoteMatch: Sendable, Codable {
    /// Page where it matched (1-based).
    public var page: Int
    /// 0 = exact after normalization, otherwise edit distance / quote length.
    public var errorRate: Double
    /// Highlight rects, normalized 0–1, origin top-left (one per line).
    public var rects: [NormalizedBox]
    public var matchedText: String
}

public enum MatchOutcome: Sendable, Codable {
    case matched(QuoteMatch)
    /// Found, but not on the page the model said.
    case matchedOtherPage(QuoteMatch, claimedPage: Int)
    case notMatched(bestErrorRate: Double?, reason: String)

    public var match: QuoteMatch? {
        switch self {
        case .matched(let m), .matchedOtherPage(let m, _): return m
        case .notMatched: return nil
        }
    }

    public var label: String {
        switch self {
        case .matched: return "matched"
        case .matchedOtherPage(let m, let c): return "matched on p.\(m.page) (claimed p.\(c))"
        case .notMatched(_, let r): return "not matched (\(r))"
        }
    }
}

public enum BoxCheck: String, Sendable, Codable {
    case ok
    case outOfPage = "out_of_page"
    case degenerate
    case wholePage = "whole_page"
}

/// Quote → word boxes on the PDF text layer. One instance per document (caches normalized pages).
public final class QuoteMatcher: @unchecked Sendable {
    public let document: PDFDocument
    private var cache: [Int: NormalizedText] = [:]
    private let lock = NSLock()
    /// Max accepted (edit distance / quote length) for fuzzy matches.
    public var maxErrorRate: Double = 0.12

    public init?(url: URL) {
        guard let d = PDFDocument(url: url) else { return nil }
        document = d
    }

    public init(document: PDFDocument) {
        self.document = document
    }

    public var pageCount: Int { document.pageCount }

    /// True when the page has a usable text layer (else: OCR needed, M3).
    public func hasTextLayer(page: Int) -> Bool {
        (normalized(page: page)?.chars.count ?? 0) > 40
    }

    func normalized(page: Int) -> NormalizedText? {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[page] { return c }
        guard page >= 1, page <= document.pageCount, let p = document.page(at: page - 1) else { return nil }
        let n = NormalizedText(p.string ?? "")
        cache[page] = n
        return n
    }

    /// Search the claimed page first, then its neighbours, then the whole document.
    public func match(quote: String, page claimed: Int) -> MatchOutcome {
        let q = NormalizedText(quote).chars
        guard q.count >= 4 else { return .notMatched(bestErrorRate: nil, reason: "quote too short") }
        var best: Double?
        var order = [claimed]
        for d in [1, -1] where claimed + d >= 1 && claimed + d <= pageCount { order.append(claimed + d) }
        order += (1...max(pageCount, 1)).filter { !order.contains($0) }
        for p in order where p >= 1 && p <= pageCount {
            guard let text = normalized(page: p), !text.chars.isEmpty else { continue }
            guard let (range, err) = Self.bestSubstring(q, in: text.chars) else { continue }
            best = min(best ?? err, err)
            if err <= maxErrorRate {
                let m = buildMatch(page: p, text: text, range: range, err: err)
                return p == claimed ? .matched(m) : .matchedOtherPage(m, claimedPage: claimed)
            }
        }
        if !(1...max(pageCount, 1)).contains(claimed) {
            return .notMatched(bestErrorRate: best, reason: "page \(claimed) out of range")
        }
        if !hasTextLayer(page: claimed) {
            return .notMatched(bestErrorRate: best, reason: "no text layer on p.\(claimed)")
        }
        return .notMatched(bestErrorRate: best, reason: best.map { String(format: "best error %.0f%%", $0 * 100) } ?? "no text")
    }

    private func buildMatch(page: Int, text: NormalizedText, range: Range<Int>, err: Double) -> QuoteMatch {
        let ns = text.originalRange(range)
        var rects: [NormalizedBox] = []
        var matched = ""
        if let p = document.page(at: page - 1) {
            let bounds = p.bounds(for: .cropBox)
            if let sel = p.selection(for: ns) {
                matched = sel.string ?? ""
                for line in sel.selectionsByLine() {
                    let r = line.bounds(for: p)
                    guard r.width > 0, r.height > 0 else { continue }
                    rects.append(NormalizedBox(
                        x: (r.minX - bounds.minX) / bounds.width,
                        y: 1 - (r.maxY - bounds.minY) / bounds.height,
                        w: r.width / bounds.width,
                        h: r.height / bounds.height))
                }
            }
        }
        return QuoteMatch(page: page, errorRate: err, rects: rects, matchedText: matched)
    }

    /// Approximate substring match (Sellers): min edit distance of `q` against any substring of `t`.
    /// Returns the matched range in `t` and distance / |q|.
    static func bestSubstring(_ q: [UInt32], in t: [UInt32]) -> (Range<Int>, Double)? {
        let m = q.count, n = t.count
        guard m > 0, n > 0 else { return nil }
        // Fast path: exact.
        if n >= m {
            let first = q[0]
            var i = 0
            while i <= n - m {
                if t[i] == first && t[i..<(i + m)].elementsEqual(q) { return (i..<(i + m), 0) }
                i += 1
            }
        }
        // prev[j] = cost of matching q[0..<i] ending at t[j-1]; start[j] = substring start.
        var prev = [Int](repeating: 0, count: n + 1)
        var prevStart = Array(0...n)
        var cur = [Int](repeating: 0, count: n + 1)
        var curStart = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            cur[0] = i
            curStart[0] = 0
            for j in 1...n {
                let sub = prev[j - 1] + (q[i - 1] == t[j - 1] ? 0 : 1)
                let del = prev[j] + 1      // skip q char
                let ins = cur[j - 1] + 1   // skip t char
                if sub <= del && sub <= ins {
                    cur[j] = sub; curStart[j] = prevStart[j - 1]
                } else if del <= ins {
                    cur[j] = del; curStart[j] = prevStart[j]
                } else {
                    cur[j] = ins; curStart[j] = curStart[j - 1]
                }
            }
            swap(&prev, &cur)
            swap(&prevStart, &curStart)
        }
        var bestJ = 1
        for j in 1...n where prev[j] < prev[bestJ] { bestJ = j }
        let start = min(prevStart[bestJ], bestJ - 1)
        return (start..<bestJ, Double(prev[bestJ]) / Double(m))
    }

    /// SPEC §3: box must be inside the page and not degenerate. Whole-page boxes are flagged
    /// (they add nothing over the page fallback).
    public static func check(box b: NormalizedBox) -> BoxCheck {
        let eps = 0.02
        if b.x < -eps || b.y < -eps || b.x + b.w > 1 + eps || b.y + b.h > 1 + eps { return .outOfPage }
        if b.w < 0.02 || b.h < 0.02 { return .degenerate }
        if b.area > 0.85 { return .wholePage }
        return .ok
    }
}
