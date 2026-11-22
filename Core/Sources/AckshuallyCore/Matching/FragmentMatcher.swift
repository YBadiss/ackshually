import Foundation

/// Layout-tolerant text matching (spec §4, step 2): covers a quote with long fragments that each
/// match the page text, with unrelated text allowed in between.
///
/// Multi-column pages interleave lines from the main column, sidebars and boxes in the PDF text
/// layer (Root p.15: "…Remove all enemy\n»\n2nd\nSpread Sympathy…\npieces there and place…"), so a
/// word-for-word quote isn't one contiguous run. This finds the fragments on the normalized text
/// (same normalization as `NormalizedText`); `LayoutCheck` then decides from their geometry whether
/// they form one block on the page.
///
/// Guards against assembling a quote from common words: a fragment needs at least
/// `minFragmentChars` normalized characters and `minFragmentWords` words, seeds are exact runs of
/// at least `seedChars`, and only small gaps (≤ `maxGap` characters on either side, e.g. a
/// decorative initial missing from the text layer) are bridged inside a fragment.
enum FragmentMatcher {
    struct Fragment: Equatable {
        /// Range in the quote's normalized characters.
        var quote: Range<Int>
        /// Range in the page's normalized characters.
        var text: Range<Int>
        /// Characters skipped inside the fragment (bridged gaps).
        var errors: Int
    }

    static let seedChars = 10
    static let minFragmentChars = 20
    static let minFragmentWords = 4
    static let maxGap = 3
    /// Exact characters needed to extend a fragment (after a bridged gap, or right after it when a
    /// neighbouring fragment had claimed the characters): a single coincidental letter ("b" of
    /// "by" against the "B" of "Battle") must not stretch a fragment onto other text.
    static let resumeChars = 4

    /// Fragments ordered by position in the quote, each at least `minFragmentChars` long and
    /// `minFragmentWords` words. `wordStarts[i]` is true when quote char `i` starts a word.
    static func fragments(_ q: [UInt32], wordStarts: [Bool], in t: [UInt32]) -> [Fragment] {
        let m = q.count, n = t.count
        guard m >= minFragmentChars, n >= minFragmentChars else { return [] }
        var qUsed = [Bool](repeating: false, count: m)
        var tUsed = [Bool](repeating: false, count: n)
        var found: [Fragment] = []
        while let seed = longestCommonRun(q, qUsed, t, tUsed), seed.quote.count >= seedChars {
            // Trim to whole words before claiming characters, so a letter grabbed from the next
            // word stays available to the fragment that really holds it.
            let f = extend(seed, q, qUsed, t, tUsed)
            let kept = trimToWords(f, wordStarts)
            let claim = kept ?? f
            for i in claim.quote { qUsed[i] = true }
            for j in claim.text { tUsed[j] = true }
            if let kept { found.append(kept) }
        }
        return found
            .filter { $0.quote.count >= minFragmentChars && words(in: $0.quote, wordStarts) >= minFragmentWords }
            .sorted { $0.quote.lowerBound < $1.quote.lowerBound }
    }

    /// Drops partial words at both ends of a fragment (in the quote): an exact run can end on a
    /// coincidental letter ("…extra actions" + "b" of "by" against "…extra actions\n» B" of "Battle").
    /// The page range is trimmed by the same amounts (ends are exact runs).
    static func trimToWords(_ f: Fragment, _ wordStarts: [Bool]) -> Fragment? {
        var lo = f.quote.lowerBound, hi = f.quote.upperBound
        while lo < hi && !wordStarts[lo] { lo += 1 }
        while hi > lo && hi < wordStarts.count && !wordStarts[hi] { hi -= 1 }
        guard hi > lo else { return nil }
        let t = (f.text.lowerBound + (lo - f.quote.lowerBound))..<(f.text.upperBound - (f.quote.upperBound - hi))
        return t.isEmpty ? nil : Fragment(quote: lo..<hi, text: t, errors: f.errors)
    }

    /// Words that start inside `r` (a fragment starting mid-word doesn't count that word).
    static func words(in r: Range<Int>, _ wordStarts: [Bool]) -> Int {
        r.reduce(0) { $0 + (wordStarts[$1] ? 1 : 0) }
    }

    /// Normalized chars of `quote` that start a word: the first one, and any that follow dropped
    /// characters (spaces, punctuation, dashes).
    static func wordStarts(_ n: NormalizedText) -> [Bool] {
        n.origin.indices.map { i in
            i == 0 || n.origin[i].location > n.origin[i - 1].location + n.origin[i - 1].length
        }
    }

    /// Longest exact run of unused quote chars that also appears in unused page chars.
    private static func longestCommonRun(_ q: [UInt32], _ qUsed: [Bool], _ t: [UInt32], _ tUsed: [Bool]) -> Fragment? {
        let n = t.count
        var prev = [Int](repeating: 0, count: n + 1)
        var cur = [Int](repeating: 0, count: n + 1)
        var best = 0, bestI = 0, bestJ = 0
        for i in 1...q.count {
            let qc = q[i - 1], qFree = !qUsed[i - 1]
            for j in 1...n {
                if qFree && !tUsed[j - 1] && t[j - 1] == qc {
                    let l = prev[j - 1] + 1
                    cur[j] = l
                    if l > best { best = l; bestI = i; bestJ = j }
                } else {
                    cur[j] = 0
                }
            }
            swap(&prev, &cur)
        }
        guard best > 0 else { return nil }
        return Fragment(quote: (bestI - best)..<bestI, text: (bestJ - best)..<bestJ, errors: 0)
    }

    /// Grows a seed in both directions across small gaps (a missing glyph, a typo) as long as
    /// at least `resumeChars` exact characters follow the gap.
    private static func extend(_ seed: Fragment, _ q: [UInt32], _ qUsed: [Bool], _ t: [UInt32], _ tUsed: [Bool]) -> Fragment {
        var f = seed
        func free(_ i: Int, _ j: Int) -> Bool {
            i >= 0 && j >= 0 && i < q.count && j < t.count && !qUsed[i] && !tUsed[j] && q[i] == t[j]
        }
        /// The skipped characters themselves must exist and belong to no other fragment.
        func gapFree(_ qs: Range<Int>, _ ts: Range<Int>) -> Bool {
            qs.lowerBound >= 0 && ts.lowerBound >= 0 && qs.upperBound <= q.count && ts.upperBound <= t.count
                && !qs.contains { qUsed[$0] } && !ts.contains { tUsed[$0] }
        }
        // Right.
        while true {
            var step: (dq: Int, dt: Int, run: Int)?
            search: for cost in 0...maxGap {
                for dq in 0...cost {
                    let dt = cost - dq
                    guard gapFree(f.quote.upperBound..<(f.quote.upperBound + dq), f.text.upperBound..<(f.text.upperBound + dt)) else { continue }
                    var run = 0
                    while free(f.quote.upperBound + dq + run, f.text.upperBound + dt + run) { run += 1 }
                    if run >= resumeChars { step = (dq, dt, run); break search }
                }
            }
            guard let s = step else { break }
            f.quote = f.quote.lowerBound..<(f.quote.upperBound + s.dq + s.run)
            f.text = f.text.lowerBound..<(f.text.upperBound + s.dt + s.run)
            f.errors += max(s.dq, s.dt)
        }
        // Left.
        while true {
            var step: (dq: Int, dt: Int, run: Int)?
            search: for cost in 0...maxGap {
                for dq in 0...cost {
                    let dt = cost - dq
                    guard gapFree((f.quote.lowerBound - dq)..<f.quote.lowerBound, (f.text.lowerBound - dt)..<f.text.lowerBound) else { continue }
                    var run = 0
                    while free(f.quote.lowerBound - 1 - dq - run, f.text.lowerBound - 1 - dt - run) { run += 1 }
                    if run >= resumeChars { step = (dq, dt, run); break search }
                }
            }
            guard let s = step else { break }
            f.quote = (f.quote.lowerBound - s.dq - s.run)..<f.quote.upperBound
            f.text = (f.text.lowerBound - s.dt - s.run)..<f.text.upperBound
            f.errors += max(s.dq, s.dt)
        }
        return f
    }
}
