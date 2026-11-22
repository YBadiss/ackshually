import Foundation
import CoreGraphics

/// Where the characters of a text range really are on the page.
///
/// PDFKit's per-character geometry (`PDFPage.characterBounds(at:)`, and so the bounds of
/// `selection(for: NSRange)`) is not indexed like `PDFPage.string`: the geometry has no entries
/// for the line breaks the string contains, and on some PDFs it drifts a few more characters
/// (synthesized spaces). Taking the bounds at the string index puts the box several words to the
/// right, wrapping onto the following lines (Azul p.3: "On your turn…" boxed "turn, you must … EITHER a) Pi"
/// across three lines). Seen on every rulebook and on the generated fixture, macOS and iOS 27.
///
/// The fix is self-checking: for each candidate mapping `geometry index = i − newlines(before i) − d`
/// (and the plain `i − d`, in case PDFKit is fixed), correlate the box widths with the expected
/// widths of the characters (an "m" is wide, an "i" narrow). The right mapping correlates at
/// r ≈ 0.8–0.95; wrong ones at ≈ 0. Each line of the quote (a segment between line breaks) is
/// re-checked near the overall mapping, since the drift can change inside a long quote.
/// If nothing correlates well enough, there is no geometry: better the whole page than a box in
/// the wrong place.
public enum GlyphLocator {
    public struct Located: Sendable, Equatable {
        /// One rect per visual line, in page space (PDF points, origin bottom-left).
        public var rects: [CGRect]
        /// Correlation of the chosen mapping over the whole range (0–1).
        public var score: Double
    }

    /// Minimum correlation to trust a mapping.
    public static let minScore = 0.6
    static let offsets = -10...80
    static let segmentMinChars = 10

    /// - Parameters:
    ///   - range: UTF-16 range in `string` (the matched quote).
    ///   - piecewise: when no single mapping fits, try word chunks (`piecewise(…)`).
    ///   - bounds: geometry by geometry index (`PDFPage.characterBounds(at:)`).
    public static func locate(range: NSRange, in string: NSString, piecewise allowPiecewise: Bool = true,
                              bounds: (Int) -> CGRect) -> Located? {
        guard range.length > 0, range.location >= 0, range.location + range.length <= string.length else { return nil }
        var newlines = [Int](repeating: 0, count: range.location + range.length + 1)
        for i in 0..<(range.location + range.length) {
            newlines[i + 1] = newlines[i] + (isNewline(string.character(at: i)) ? 1 : 0)
        }
        let all = Array(range.location..<(range.location + range.length)).filter { !isNewline(string.character(at: $0)) }
        var cache: [Int: CGRect] = [:]
        func box(_ g: Int) -> CGRect {
            if let b = cache[g] { return b }
            let b = (g >= 0 && g < string.length) ? bounds(g) : .zero
            cache[g] = b
            return b
        }
        func map(_ m: Mapping, _ i: Int) -> Int { i - (m.skipsNewlines ? newlines[i] : 0) - m.offset }
        func score(_ m: Mapping, _ idx: [Int]) -> Double {
            var expected: [Double] = [], actual: [Double] = []
            for i in idx {
                let c = string.character(at: i)
                guard !isSpace(c) else { continue }
                expected.append(width(of: c))
                let b = box(map(m, i))
                actual.append(b.height > 0 ? Double(b.width) : 0)
            }
            return correlation(expected, actual)
        }
        func best(_ idx: [Int], candidates: [Mapping]) -> (Mapping, Double) {
            var top = (candidates[0], -2.0)
            for m in candidates {
                let s = score(m, idx)
                if s > top.1 + 1e-9 { top = (m, s) }
            }
            return top
        }

        let candidates = [true, false].flatMap { skip in offsets.map { Mapping(skipsNewlines: skip, offset: $0) } }
        var (global, globalScore) = best(all, candidates: candidates)
        // Prefer the common case (line breaks skipped, no drift) when it fits about as well: short
        // quotes can correlate by chance with a far-off mapping.
        let usual = Mapping(skipsNewlines: true, offset: 0)
        let usualScore = score(usual, all)
        if usualScore >= minScore, usualScore >= globalScore - 0.08 { (global, globalScore) = (usual, usualScore) }
        guard globalScore >= minScore else {
            guard allowPiecewise else { return nil }
            return piecewise(range: range, in: string, candidates: candidates, score: score, best: best, map: map, box: box)
        }

        // Per line of the quote: keep the global mapping unless a nearby one fits that line clearly better.
        var segments: [[Int]] = [[]]
        for i in range.location..<(range.location + range.length) {
            if isNewline(string.character(at: i)) { segments.append([]) } else { segments[segments.count - 1].append(i) }
        }
        var chars: [CGRect] = []
        for seg in segments where !seg.isEmpty {
            var m = global
            if seg.filter({ !isSpace(string.character(at: $0)) }).count >= segmentMinChars {
                let near = (-6...12).map { Mapping(skipsNewlines: global.skipsNewlines, offset: global.offset + $0) }
                let (local, s) = best(seg, candidates: near)
                if s >= minScore, s > score(global, seg) + 0.1 { m = local }
            }
            for i in seg where !isSpace(string.character(at: i)) {
                let b = box(map(m, i))
                if b.width > 0, b.height > 0 { chars.append(b) }
            }
        }
        let lines = lineRects(chars)
        return lines.isEmpty ? nil : Located(rects: lines, score: globalScore)
    }

    /// Chunks (whole words) used by the piecewise fallback, in non-space characters.
    static let chunkMinChars = 16
    /// Correlation a chunk needs on its own: stricter than `minScore`, chunks are short.
    static let chunkMinScore = 0.75
    /// The piecewise result must place at least this share of the range's characters.
    static let piecewiseMinShare = 0.4
    /// Piecewise lines shorter than this (PDF points) are rejected: text-layer text drawn tiny
    /// or hidden under artwork (Root p.9's ambush card) that readers can't see.
    static let piecewiseMinLineHeight: CGFloat = 4

    /// Fallback when no single mapping fits the whole range: the mapping changes inside it (a
    /// ligature with one glyph for "ffi", glyphs stored out of order after an interleaved sidebar;
    /// Root p.15). Split into word chunks, anchor on the best-correlating chunk, then grow to the
    /// neighbouring chunks only while each one correlates on its own *and* lands right after the
    /// previous one on the page (same line to the right, or the start of a following line).
    /// Chunks that don't fit end the growth in that direction: those words get no box.
    private static func piecewise(range: NSRange, in string: NSString, candidates: [Mapping],
                                  score: (Mapping, [Int]) -> Double,
                                  best: ([Int], [Mapping]) -> (Mapping, Double),
                                  map: (Mapping, Int) -> Int, box: (Int) -> CGRect) -> Located? {
        // Chunks of whole words, ≥ chunkMinChars non-space characters each (the rest joins the last one).
        var chunks: [[Int]] = [], cur: [Int] = []
        var nonSpace = 0
        for i in range.location..<(range.location + range.length) {
            let c = string.character(at: i)
            if isNewline(c) || isSpace(c) {
                if nonSpace >= chunkMinChars { chunks.append(cur); cur = []; nonSpace = 0 }
                continue
            }
            cur.append(i); nonSpace += 1
        }
        if !cur.isEmpty {
            if nonSpace < chunkMinChars, !chunks.isEmpty { chunks[chunks.count - 1] += cur } else { chunks.append(cur) }
        }
        let total = chunks.reduce(0) { $0 + $1.count }
        guard total >= 2 * chunkMinChars, chunks.count >= 2 else { return nil }

        let fits = chunks.map { best($0, candidates) }
        guard let anchor = fits.indices.max(by: { fits[$0].1 < fits[$1].1 }), fits[anchor].1 >= chunkMinScore else { return nil }
        func boxes(_ ci: Int, _ m: Mapping) -> [CGRect] {
            chunks[ci].map { box(map(m, $0)) }.filter { $0.width > 0 && $0.height > 0 }
        }
        func local(_ ci: Int, near m: Mapping) -> (Mapping, Double) {
            best(chunks[ci], (-8...8).map { Mapping(skipsNewlines: m.skipsNewlines, offset: m.offset + $0) })
        }
        /// `b` starts where `a` ends: same line to the right, or a following line further left.
        func follows(_ a: [CGRect], _ b: [CGRect]) -> Bool {
            guard let x = a.last, let y = b.first else { return false }
            let h = max(x.height, y.height)
            if abs(x.midY - y.midY) < 0.6 * h { return y.minX >= x.minX && y.minX - x.maxX <= 3 * h }
            return y.midY < x.midY && x.midY - y.midY <= 2.5 * h && y.minX < x.maxX   // PDF space: below = smaller y
        }
        var placed: [Int: (Mapping, Double, [CGRect])] = [anchor: (fits[anchor].0, fits[anchor].1, boxes(anchor, fits[anchor].0))]
        var ci = anchor + 1
        while ci < chunks.count, let prev = placed[ci - 1] {
            let (m, sc) = local(ci, near: prev.0)
            let b = boxes(ci, m)
            guard sc >= chunkMinScore, follows(prev.2, b) else { break }
            placed[ci] = (m, sc, b); ci += 1
        }
        ci = anchor - 1
        while ci >= 0, let next = placed[ci + 1] {
            let (m, sc) = local(ci, near: next.0)
            let b = boxes(ci, m)
            guard sc >= chunkMinScore, follows(b, next.2) else { break }
            placed[ci] = (m, sc, b); ci -= 1
        }
        let located = placed.keys.reduce(0) { $0 + chunks[$1].count }
        guard Double(located) >= piecewiseMinShare * Double(total) else { return nil }
        let chars = placed.keys.sorted().flatMap { k in
            chunks[k].filter { !isSpace(string.character(at: $0)) }.map { box(map(placed[k]!.0, $0)) }
        }.filter { $0.width > 0 && $0.height > 0 }
        let lines = lineRects(chars)
        guard lines.allSatisfy({ $0.height >= piecewiseMinLineHeight }) else { return nil }
        let weighted = placed.reduce(0.0) { $0 + $1.value.1 * Double(chunks[$1.key].count) } / Double(located)
        return lines.isEmpty ? nil : Located(rects: lines, score: weighted)
    }

    struct Mapping: Equatable {
        var skipsNewlines: Bool
        var offset: Int
    }

    /// Consecutive character boxes → one rect per visual line. Outlier-tall glyphs (decorative
    /// initials, broken metrics) don't stretch the line.
    static func lineRects(_ chars: [CGRect]) -> [CGRect] {
        guard !chars.isEmpty else { return [] }
        let heights = chars.map(\.height).sorted()
        let typical = heights[heights.count / 2]
        var lines: [CGRect] = []
        var current = CGRect.null
        var last: CGRect?
        for b in chars where b.height <= typical * 2 {
            if let p = last {
                let newLine = abs(b.midY - p.midY) > max(p.height, b.height) * 0.6 || b.minX < p.minX - typical * 2
                if newLine { lines.append(current); current = .null }
            }
            current = current.union(b)
            last = b
        }
        if !current.isNull { lines.append(current) }
        return lines
    }

    static func isNewline(_ c: unichar) -> Bool { c == 10 || c == 13 || c == 0x2028 || c == 0x2029 }
    static func isSpace(_ c: unichar) -> Bool { c == 32 || c == 9 || c == 0xA0 || c == 0xFFFC }

    /// Rough advance width of a character relative to the font size (proportional text fonts).
    static func width(of c: unichar) -> Double {
        guard let scalar = UnicodeScalar(c) else { return 0.52 }
        let ch = Character(scalar)
        if "ijl.,;:'’!|I".contains(ch) { return 0.28 }
        if "ftr()-–".contains(ch) { return 0.38 }
        if "mwMW".contains(ch) { return 0.85 }
        if ch.isUppercase { return 0.68 }
        if ch.isNumber { return 0.5 }
        return 0.52
    }

    static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        let n = Double(a.count)
        guard a.count > 3, a.count == b.count else { return -1 }
        let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
        var c = 0.0, va = 0.0, vb = 0.0
        for i in a.indices {
            c += (a[i] - ma) * (b[i] - mb)
            va += (a[i] - ma) * (a[i] - ma)
            vb += (b[i] - mb) * (b[i] - mb)
        }
        return va > 0 && vb > 0 ? c / (va * vb).squareRoot() : -1
    }
}
