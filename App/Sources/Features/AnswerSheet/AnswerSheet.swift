import SwiftUI

/// The answer on compact screens: a system sheet (S5/S7/S9) with three detents sized from the
/// content (collapsed = verdict + proof line, medium = + step cards and branches, large = all),
/// background interaction up to medium so the PDF stays pinchable and pannable under it, and no
/// swipe-to-dismiss (the header's close button closes). Reports its top edge so the PDF can
/// center evidence in the part of the page that is still visible.
///
/// The detent heights hold still while an answer streams: they are taken from the first layout
/// (header + loading card + follow-up row, all laid out from the first token) and frozen until the
/// answer is done; after that they only grow (late content such as branch rows), never shrink,
/// while the sheet is up. Re-measuring on every streamed event made the sheet shrink under the
/// verdict and grow back each time (owner, 2026-11-22: "the panel hides and reappears").
///
/// A height change also changes the detent's identity (`.height(x)`): if the sheet sits on the
/// detent that changes, the old one leaves the set and the system sheet snaps to another detent
/// for a moment. So the detent being left stays in the set (`stale`) until the next selection
/// change, and the sheet glides from it to the new height.
struct AnswerSheet: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    var presentation: ViewerPresentation
    /// Window height, for capping the detents.
    var containerHeight: CGFloat
    var onTopChange: (CGFloat) -> Void
    @Environment(\.theme) private var theme
    /// Latest content heights.
    @State private var measured = AnswerMetrics()
    /// Heights the detents use: frozen while streaming, grow-only otherwise.
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
        .onChange(of: model.isBusy) { resize() }
        .onChange(of: typeSize) { metrics = measured }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { onTopChange($0) }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .presentationDetents(detents, selection: selection)
        .presentationBackgroundInteraction(.enabled(upThrough: medium))
        .presentationBackground(theme.colors.sheet)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
        .viewerDialogs(presentation, model: model, active: true)
    }

    private func resize() {
        let next = metrics.next(measured: measured, streaming: model.isBusy)
        guard next != metrics else { return }
        let before = selected
        metrics = next
        if selected != before { stale = before }
    }

    private var selected: PresentationDetent {
        switch model.detent {
        case .collapsed: collapsed
        case .medium: medium
        case .expanded: .large
        }
    }

    private var collapsed: PresentationDetent {
        guard metrics.collapsed > 0 else { return .fraction(0.22) }
        let h = metrics.collapsed + theme.spacing.s + bottomInset
        return .height(min(h, containerHeight * theme.layout.sheetCollapsedMaxFraction))
    }

    /// Same as collapsed until there is more than the header (S4: before the cards arrive).
    private var medium: PresentationDetent {
        guard metrics.medium > metrics.collapsed + theme.spacing.xl else { return collapsed }
        return .height(min(metrics.medium + bottomInset, containerHeight * theme.layout.sheetMediumMaxFraction))
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
