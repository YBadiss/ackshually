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
    ///   - bounds: geometry by geometry index (`PDFPage.characterBounds(at:)`).
    public static func locate(range: NSRange, in string: NSString, bounds: (Int) -> CGRect) -> Located? {
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
        guard globalScore >= minScore else { return nil }

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
