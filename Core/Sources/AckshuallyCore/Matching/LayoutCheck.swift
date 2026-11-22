import Foundation
import CoreGraphics

/// Do located fragments form one coherent block on the page? (spec §4, step 2)
///
/// Fragments are taken in quote order. Two consecutive fragments belong to the same block when the
/// next one continues on the same line (to the right, a short gap: an icon or a pasted-in word) or
/// on one of the next lines (no more than `maxLineGap` line heights below, in an overlapping
/// column or wrapping back to the left within `maxWrapWidth` of the page). A block must also stay
/// within `maxBlockArea` of the page. Interleaved text (sidebars, boxes) sits *between* the
/// fragments in the text layer, not on the page, so a true quote passes; fragments that were
/// assembled from all over the page don't.
enum LayoutCheck {
    /// Vertical gap allowed between consecutive fragments, in line heights.
    static let maxLineGap = 1.6
    /// Horizontal gap allowed between fragments on the same line, in line heights.
    static let maxSameLineGap = 4.0
    /// A wrap back to the next line may not jump further left than this fraction of the page width.
    static let maxWrapWidth = 0.6
    /// Bounding box of a block, as a fraction of the page area.
    static let maxBlockArea = 0.2

    struct Block: Equatable {
        /// Indices of the fragments in the block (consecutive, in quote order).
        var fragments: Range<Int>
        /// Ink of the lines over the block's bounding box (0–1): high for a compact passage.
        var density: Double
    }

    /// Splits fragments (each: its line rects in page points, origin top-left) into coherent blocks.
    /// Fragments without rects end a block. Blocks over `maxBlockArea` are dropped.
    static func blocks(_ fragments: [[CGRect]], page: CGSize) -> [Block] {
        let heights = fragments.flatMap { $0.map(\.height) }.sorted()
        guard !heights.isEmpty, page.width > 0, page.height > 0 else { return [] }
        let lh = heights[heights.count / 2]
        var out: [Block] = []
        var start: Int?
        func close(_ end: Int) {
            guard let s = start else { return }
            let rects = fragments[s..<end].flatMap { $0 }
            let union = rects.reduce(CGRect.null) { $0.union($1) }
            let area = Double(union.width * union.height)
            if area <= maxBlockArea * Double(page.width * page.height) {
                let ink = rects.reduce(0.0) { $0 + Double($1.width * $1.height) }
                out.append(Block(fragments: s..<end, density: area > 0 ? min(1, ink / area) : 1))
            }
            start = nil
        }
        for i in fragments.indices {
            guard !fragments[i].isEmpty else { close(i); continue }
            if start != nil, !continues(fragments[i - 1], fragments[i], lineHeight: lh, pageWidth: page.width) { close(i) }
            if start == nil { start = i }
        }
        close(fragments.count)
        return out
    }

    /// Does `b` continue right after `a` on the page?
    static func continues(_ a: [CGRect], _ b: [CGRect], lineHeight lh: CGFloat, pageWidth: CGFloat) -> Bool {
        guard let last = a.last, let first = b.first else { return false }
        let ua = a.reduce(CGRect.null) { $0.union($1) }, ub = b.reduce(CGRect.null) { $0.union($1) }
        let vOverlap = min(last.maxY, first.maxY) - max(last.minY, first.minY)
        if vOverlap >= 0.5 * min(last.height, first.height) {
            // Same line: to the right, close by.
            return first.minX >= last.minX && first.minX - last.maxX <= maxSameLineGap * lh
        }
        // Next line(s): below, close.
        guard first.midY > last.midY, first.minY - last.maxY <= maxLineGap * lh else { return false }
        if min(ua.maxX, ub.maxX) - max(ua.minX, ub.minX) > 0 { return true }   // same column
        // Wrapped back to the start of the next line, within one column's reach.
        return first.minX < last.minX && last.minX - first.minX <= maxWrapWidth * pageWidth
    }
}
