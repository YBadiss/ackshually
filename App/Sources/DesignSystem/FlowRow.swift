import SwiftUI

/// Wrapping row for chips and pills (wraps instead of truncating at large text sizes).
struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.init(width: width, height: nil))
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.init(width: bounds.width, height: nil))
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .init(width: min(sz.width, bounds.width), height: sz.height))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

#Preview {
    FlowRow(spacing: 6) {
        ForEach(["✓ Stated · p.3, p.4", "No Battery? Discard all 3. ›", "Two Batteries? Keep 4 ›"], id: \.self) {
            Text($0).padding(4).background(.yellow.opacity(0.3))
        }
    }
    .padding()
}
