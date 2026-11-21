import SwiftUI

/// The answer on compact screens: a system sheet (S5/S7/S9) with three detents sized from the
/// content (collapsed = verdict + proof line, medium = + step cards and branches, large = all),
/// background interaction up to medium so the PDF stays pinchable and pannable under it, and no
/// swipe-to-dismiss (the header's close button closes). Reports its top edge so the PDF can
/// center evidence in the part of the page that is still visible.
struct AnswerSheet: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    var presentation: ViewerPresentation
    /// Window height, for capping the detents.
    var containerHeight: CGFloat
    var onTopChange: (CGFloat) -> Void
    @Environment(\.theme) private var theme
    @State private var metrics = AnswerMetrics()
    /// Home-indicator inset at the bottom of the sheet: content heights don't include it, so the
    /// collapsed detent cut off the proof line without it.
    @State private var bottomInset: CGFloat = 0

    var body: some View {
        AnswerContent(model: model, voice: voice, placement: .sheet(model.detent)) { m in
            // The question line only shows when expanded; keep the smaller detents' sizes.
            if model.detent != .expanded { metrics = m }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { onTopChange($0) }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .presentationDetents(Set(detents), selection: selection)
        .presentationBackgroundInteraction(.enabled(upThrough: medium))
        .presentationBackground(theme.colors.sheet)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
        .viewerDialogs(presentation, model: model, active: true)
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

    private var detents: [PresentationDetent] { [collapsed, medium, .large] }

    private var selection: Binding<PresentationDetent> {
        Binding {
            switch model.detent {
            case .collapsed: collapsed
            case .medium: medium
            case .expanded: .large
            }
        } set: { d in
            if d == .large { model.detent = .expanded } else if d == collapsed, medium != collapsed { model.detent = .collapsed } else { model.detent = .medium }
        }
    }
}
