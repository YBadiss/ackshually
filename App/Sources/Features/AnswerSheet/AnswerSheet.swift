import SwiftUI

/// The answer on compact screens: a system sheet (S5/S7/S9) with three detents sized from the
/// content (collapsed = verdict + proof line, medium = + step cards and branches, large = all),
/// background interaction up to medium so the PDF stays pinchable and pannable under it, and no
/// swipe-to-dismiss (the header's close button closes). Reports the height of the detent it is
/// on (or heading to) so the PDF can center evidence in the part of the page that stays visible,
/// moving together with the sheet instead of after it settles.
///
/// The detent heights hold still while an answer streams: they are taken from the first layout
/// (header + loading card + follow-up row, all laid out from the first token) and frozen until the
/// answer is done; then they fit the finished content once (late branch rows in, the loading
/// card's reserved height out), animated. Re-measuring on every streamed event made the sheet shrink under the
/// verdict and grow back each time (owner, 2026-11-22: "the panel hides and reappears").
///
/// A height change also changes the detent's identity (`.height(x)`): if the sheet sits on the
/// detent that changes, the old one leaves the set and the system sheet snaps to another detent
/// for a moment. So the detent being left stays in the set (`stale`) until the next selection
/// change, and the sheet glides from it to the new height.
struct AnswerSheet: View {
    var model: ViewerModel
    var voice: AskController
    /// Window height, for capping the detents.
    var containerHeight: CGFloat
    /// Height of the selected detent, from the window bottom: what the sheet covers once settled
    /// (nil until both detents are measured).
    var onCoveredChange: (CGFloat?) -> Void
    @Environment(\.theme) private var theme
    /// Latest content heights.
    @State private var measured = AnswerMetrics()
    /// Heights the detents use: frozen while streaming, fitted to the content otherwise.
    @State private var metrics = AnswerMetrics()
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Home-indicator inset at the bottom of the sheet: content heights don't include it, so the
    /// collapsed detent cut off the proof line without it.
    @State private var bottomInset: CGFloat = 0
    /// The selected detent from before its height last changed, kept for one transition.
    @State private var stale: PresentationDetent?

    var body: some View {
        AnswerContent(model: model, voice: voice, placement: .sheet(model.detent)) { m in
            // The question line only shows when expanded; keep the smaller detents' sizes.
            if model.detent != .expanded, m != measured { measured = m; resize() }
        }
        .onChange(of: model.session.isBusy) { resize() }
        .onChange(of: typeSize) { metrics = measured }
        .onChange(of: metrics.isSized ? coveredHeight : nil, initial: true) { _, h in onCoveredChange(h) }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .presentationDetents(detents, selection: selection)
        .presentationBackgroundInteraction(.enabled(upThrough: medium))
        .presentationBackground(theme.colors.sheet)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
        .viewerDialogs(model: model, active: true)
    }

    private func resize() {
        let next = metrics.next(measured: measured, streaming: model.session.isBusy)
        guard next != metrics else { return }
        let before = selected
        metrics = next
        // Keep the detent the sheet actually sits on: if two changes land before the sheet moves,
        // the first one's starting detent is still the one on screen.
        if selected != before, stale == nil { stale = before }
    }

    private var selected: PresentationDetent {
        switch model.detent {
        case .collapsed: collapsed
        case .medium: medium
        case .expanded: .large
        }
    }

    /// Fallback before the first measurement.
    private static let unmeasuredFraction: CGFloat = 0.22

    private var collapsedHeight: CGFloat {
        guard metrics.collapsed > 0 else { return containerHeight * Self.unmeasuredFraction }
        return min(metrics.collapsed + theme.spacing.s + bottomInset, containerHeight * theme.layout.sheetCollapsedMaxFraction)
    }

    /// Same as collapsed until there is more than the header (S4: before the cards arrive).
    private var mediumHeight: CGFloat {
        guard metrics.medium > metrics.collapsed + theme.spacing.xl else { return collapsedHeight }
        return min(metrics.medium + bottomInset, containerHeight * theme.layout.sheetMediumMaxFraction)
    }

    private var collapsed: PresentationDetent {
        metrics.collapsed > 0 ? .height(collapsedHeight) : .fraction(Self.unmeasuredFraction)
    }

    private var medium: PresentationDetent {
        metrics.medium > metrics.collapsed + theme.spacing.xl ? .height(mediumHeight) : collapsed
    }

    /// The large detent hides the PDF: keep it framed for medium, where the sheet comes back to,
    /// instead of re-centering it into the sliver above a full-height sheet.
    private var coveredHeight: CGFloat {
        model.detent == .collapsed ? collapsedHeight : mediumHeight
    }

    private var detents: Set<PresentationDetent> {
        var s: Set<PresentationDetent> = [collapsed, medium, .large]
        if let stale { s.insert(stale) }
        return s
    }

    private var selection: Binding<PresentationDetent> {
        Binding { selected } set: { d in
            // The sheet reporting the stale detent mid-transition keeps the current one.
            guard d != stale else { return }
            stale = nil
            if d == .large { model.detent = .expanded } else if d == collapsed, medium != collapsed { model.detent = .collapsed } else { model.detent = .medium }
        }
    }
}
