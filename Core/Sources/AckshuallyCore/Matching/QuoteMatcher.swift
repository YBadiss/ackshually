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

/// How a quote was found in the page text (spec §4, "Placing a highlight").
public enum MatchLayout: String, Sendable, Codable {
    /// One contiguous run of the page text.
    case continuous
    /// Long fragments in the text layer that form one block on the page (multi-column pages
    /// whose text layer interleaves lines from sidebars and boxes).
    case fragments
    /// Only part of the quote was found (at least one long fragment, in one block): that part is
    /// highlighted rather than the whole page.
    case partial
}

/// One piece of a layout-tolerant match.
public struct MatchFragment: Sendable, Codable, Equatable {
    /// Page text of the fragment.
    public var text: String
    /// Highlight rects, normalized 0–1, origin top-left (one per line).
    public var rects: [NormalizedBox]
    /// `GlyphLocator` correlation for this fragment.
    public var geometryScore: Double?

    public init(text: String, rects: [NormalizedBox], geometryScore: Double?) {
        self.text = text
        self.rects = rects
        self.geometryScore = geometryScore
    }
}

public struct QuoteMatch: Sendable, Codable {
    /// Page where it matched (1-based).
    public var page: Int
    /// 0 = exact after normalization, otherwise edit distance / quote length. For fragments:
    /// (uncovered + bridged characters) / quote length.
    public var errorRate: Double
    /// Highlight rects, normalized 0–1, origin top-left (one per line; all fragments' lines).
    public var rects: [NormalizedBox]
    public var matchedText: String
    /// How well the character geometry was located (`GlyphLocator`, 0–1; for fragments the
    /// weakest fragment); nil = not located, `rects` is empty and the app shows the whole page.
    public var geometryScore: Double?
    /// Continuous, fragments or partial.
    public var layout: MatchLayout
    /// Share of the quote's normalized characters that were found (1 for continuous matches).
    public var coverage: Double
    /// Fragments only: the pieces, in quote order.
    public var fragments: [MatchFragment]
    /// Fragments only: how compact the block is (ink of the lines / bounding box, 0–1).
    public var layoutScore: Double?

    public init(page: Int, errorRate: Double, rects: [NormalizedBox], matchedText: String, geometryScore: Double? = nil,
                layout: MatchLayout = .continuous, coverage: Double = 1, fragments: [MatchFragment] = [], layoutScore: Double? = nil) {
        self.page = page
        self.errorRate = errorRate
        self.rects = rects
        self.matchedText = matchedText
        self.geometryScore = geometryScore
        self.layout = layout
        self.coverage = coverage
        self.fragments = fragments
        self.layoutScore = layoutScore
    }

    enum CodingKeys: String, CodingKey {
        case page, errorRate, rects, matchedText, geometryScore, layout, coverage, fragments, layoutScore
    }

    /// Older records have no layout fields: they were continuous matches.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        page = try c.decode(Int.self, forKey: .page)
        errorRate = try c.decode(Double.self, forKey: .errorRate)
        rects = try c.decode([NormalizedBox].self, forKey: .rects)
        matchedText = try c.decode(String.self, forKey: .matchedText)
        geometryScore = try c.decodeIfPresent(Double.self, forKey: .geometryScore)
        layout = try c.decodeIfPresent(MatchLayout.self, forKey: .layout) ?? .continuous
        coverage = try c.decodeIfPresent(Double.self, forKey: .coverage) ?? 1
        fragments = try c.decodeIfPresent([MatchFragment].self, forKey: .fragments) ?? []
        layoutScore = try c.decodeIfPresent(Double.self, forKey: .layoutScore)
    }

    /// "", " (2 fragments, 100% of the quote)", " (61% of the quote)": appended to outcome labels.
    public var layoutLabel: String {
        switch layout {
        case .continuous: return ""
        case .fragments: return " (\(fragments.count) fragments, \(Int((coverage * 100).rounded()))% of the quote)"
        case .partial: return " (\(Int((coverage * 100).rounded()))% of the quote)"
        }
    }
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
        case .matched(let m): return m.layout == .partial ? "partial match" + m.layoutLabel : "matched" + m.layoutLabel
        case .matchedOtherPage(let m, let c): return "matched on p.\(m.page) (claimed p.\(c))" + m.layoutLabel
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
    /// Fragment / partial matches and piecewise geometry (spec §4 step 2). Off = the continuous
    /// matcher only (bench baseline: `bench rescore --continuous-only`).
    public var layoutTolerant = true

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
        // Layout-tolerant: fragments forming one block, on the claimed page then its neighbours;
        // a partial match only on the claimed page.
        let words = FragmentMatcher.wordStarts(NormalizedText(quote))
        for p in order.prefix(3) where layoutTolerant && p >= 1 && p <= pageCount {
            guard let m = fragmentMatch(q, wordStarts: words, page: p, allowPartial: p == claimed) else { continue }
            return p == claimed ? .matched(m) : .matchedOtherPage(m, claimedPage: claimed)
        }
        if !(1...max(pageCount, 1)).contains(claimed) {
            return .notMatched(bestErrorRate: best, reason: "page \(claimed) out of range")
        }
        if !hasTextLayer(page: claimed) {
            return .notMatched(bestErrorRate: best, reason: "no text layer on p.\(claimed)")
        }
        return .notMatched(bestErrorRate: best, reason: best.map { String(format: "best error %.0f%%", $0 * 100) } ?? "no text")
    }

    /// First page of `candidates` (in order) whose text contains `quote` within `maxErrorRate`.
    /// Used to correct evidence pages on excerpt answers, where the model can mis-number pages.
    public func locate(quote: String, candidates: [Int]) -> Int? {
        let q = NormalizedText(quote).chars
        guard q.count >= 4 else { return nil }
        var seen = Set<Int>()
        for p in candidates where p >= 1 && p <= pageCount && seen.insert(p).inserted {
            guard let text = normalized(page: p), !text.chars.isEmpty,
                  let (_, err) = Self.bestSubstring(q, in: text.chars) else { continue }
            if err <= maxErrorRate { return p }
        }
        return nil
    }

    /// Share of the quote a fragment match must cover.
    public var minFragmentCoverage = 0.85
    /// A partial match needs one fragment at least this long (normalized chars) and this many words…
    public var partialMinFragmentChars = 30
    public var partialMinFragmentWords = 6
    /// …and must cover at least this share of the quote.
    public var partialMinCoverage = 0.3

    /// Fragment match on one page (spec §4 step 2): fragments → located rects → one coherent block.
    func fragmentMatch(_ q: [UInt32], wordStarts: [Bool], page: Int, allowPartial: Bool) -> QuoteMatch? {
        guard let text = normalized(page: page), let p = document.page(at: page - 1) else { return nil }
        let found = FragmentMatcher.fragments(q, wordStarts: wordStarts, in: text.chars)
        guard !found.isEmpty else { return nil }
        // A partial match is only possible with one long fragment; a full one only with enough coverage.
        let total = found.reduce(0) { $0 + $1.quote.count }
        let hasLong = found.contains {
            $0.quote.count >= partialMinFragmentChars && FragmentMatcher.words(in: $0.quote, wordStarts) >= partialMinFragmentWords
        }
        guard Double(total) / Double(q.count) >= minFragmentCoverage || (allowPartial && hasLong) else { return nil }

        let bounds = p.bounds(for: .cropBox)
        let ns = text.original as NSString
        // Each fragment's lines in page points, origin top-left (LayoutCheck) and normalized (QuoteMatch).
        var located: [(fragment: FragmentMatcher.Fragment, points: [CGRect], match: MatchFragment)] = []
        for f in found {
            let r = text.originalRange(f.text)
            // Not `selection(for:)`: its indexing is off (see GlyphLocator) and grabs neighbours.
            let piece = ns.substring(with: r)
            guard let l = GlyphLocator.locate(range: r, in: ns, bounds: { p.characterBounds(at: $0) }) else {
                located.append((f, [], MatchFragment(text: piece, rects: [], geometryScore: nil)))
                continue
            }
            let points = l.rects.map { CGRect(x: $0.minX - bounds.minX, y: bounds.maxY - $0.maxY, width: $0.width, height: $0.height) }
            let boxes = points.map {
                NormalizedBox(x: $0.minX / bounds.width, y: $0.minY / bounds.height, w: $0.width / bounds.width, h: $0.height / bounds.height)
            }
            located.append((f, points, MatchFragment(text: piece, rects: boxes, geometryScore: l.score)))
        }
        let blocks = LayoutCheck.blocks(located.map(\.points), page: bounds.size)
        func covered(_ b: LayoutCheck.Block) -> Int { located[b.fragments].reduce(0) { $0 + $1.fragment.quote.count } }
        guard let best = blocks.max(by: { covered($0) < covered($1) }) else { return nil }
        let parts = Array(located[best.fragments])
        let coverage = Double(covered(best)) / Double(q.count)
        let layout: MatchLayout
        if coverage >= minFragmentCoverage && parts.count > 1 {
            layout = .fragments
        } else {
            let long = parts.contains {
                $0.fragment.quote.count >= partialMinFragmentChars
                    && FragmentMatcher.words(in: $0.fragment.quote, wordStarts) >= partialMinFragmentWords
            }
            guard allowPartial, long, coverage >= partialMinCoverage else { return nil }
            layout = .partial
        }
        let errors = parts.reduce(0) { $0 + $1.fragment.errors }
        return QuoteMatch(page: page, errorRate: min(1, (1 - coverage) + Double(errors) / Double(q.count)),
                          rects: parts.flatMap(\.match.rects), matchedText: parts.map(\.match.text).joined(separator: " … "),
                          geometryScore: parts.compactMap(\.match.geometryScore).min(), layout: layout, coverage: coverage,
                          fragments: parts.map(\.match), layoutScore: best.density)
    }

    private func buildMatch(page: Int, text: NormalizedText, range: Range<Int>, err: Double) -> QuoteMatch {
        let ns = text.originalRange(range)
        var rects: [NormalizedBox] = []
        var matched = ""
        var score: Double?
        if let p = document.page(at: page - 1) {
            let bounds = p.bounds(for: .cropBox)
            matched = p.selection(for: ns)?.string ?? (text.original as NSString).substring(with: ns)
            // Not `selection(for:).selectionsByLine()`: its geometry is misindexed (see GlyphLocator).
            if let located = GlyphLocator.locate(range: ns, in: text.original as NSString, piecewise: layoutTolerant, bounds: { p.characterBounds(at: $0) }) {
                score = located.score
                for r in located.rects {
                    rects.append(NormalizedBox(
                        x: (r.minX - bounds.minX) / bounds.width,
                        y: 1 - (r.maxY - bounds.minY) / bounds.height,
                        w: r.width / bounds.width,
                        h: r.height / bounds.height))
                }
            }
        }
        return QuoteMatch(page: page, errorRate: err, rects: rects, matchedText: matched, geometryScore: score)
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
