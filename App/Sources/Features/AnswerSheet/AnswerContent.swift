import SwiftUI

/// The whole answer in one scrolling column, wired to the injected `ViewerModel`. The sheet
/// reveals it top-down (collapsed → header, medium → + step cards and branches, large → + steps,
/// assumptions, feedback, follow-up); the inspector shows all of it.
/// Margins are the scroll view's content margins (`spacing.sheetMargin` at the sides,
/// `spacing.sheetTop` under the sheet's grabber); only the step shelf runs edge to edge.
/// While an answer streams, the shelf (a loading card) and the follow-up row are laid out from
/// the first token, so the sheet can be sized once and the content fills in place.
struct AnswerContent: View {
    var model: ViewerModel
    var voice: AskController
    var placement: AnswerPlacement
    var onMetrics: (AnswerMetrics) -> Void = { _ in }
    @Environment(\.theme) private var theme
    @State private var metrics = AnswerMetrics()

    private nonisolated static let space = "answerContent"
    private var answered: Bool { model.navigator.header?.state == .answered }
    /// Shelf and footer row: once answered, and as placeholders while the answer streams.
    private var showsShelf: Bool { answered || model.session.isBusy }
    private var topMargin: CGFloat { placement == .inspector ? theme.spacing.xl : theme.spacing.sheetTop }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    if let h = model.navigator.header {
                        AnswerHeader(content: h, showsQuestion: placement.isExpanded,
                                     onStop: stop, onRetry: model.session.retry,
                                     onSettings: { model.presentation.settings = true }, onClose: close)
                            .id("top")
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).maxY } action: {
                                metrics.collapsed = $0 + topMargin
                                onMetrics(metrics)
                            }
                    }
                    if showsShelf {
                        AnswerShelf(model: model)
                            // Edge to edge: the cards peek from the sheet's sides.
                            .padding(.horizontal, -theme.spacing.sheetMargin)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    // Sheet below large: follow-up + thumbs in their own row (expanded / inspector
                    // have them in the full sections below). Shown, disabled, while streaming.
                    if model.session.canFollowUp || model.session.isBusy, !placement.isExpanded {
                        AnswerFooterRow(draft: Bindable(model.session).draft, voice: voice, rating: model.session.currentRating,
                                        onRate: model.session.rate, onSend: model.session.ask)
                            .disabled(!model.session.canFollowUp)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    if answered, !model.navigator.branchRows.isEmpty {
                        BranchRows(rows: model.navigator.branchRows, onSelect: selectBranch)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    // The medium detent ends here; what follows shows when expanded. The stack's
                    // spacing above this marker is the bottom margin of the medium detent.
                    Color.clear.frame(height: 0)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: {
                            metrics.medium = $0 + topMargin
                            onMetrics(metrics)
                        }
                    if answered {
                        FullAnswerSections(model: model, collapsesOnSelect: placement != .inspector)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    if model.session.canFollowUp, placement.isExpanded {
                        FollowUpSection(session: model.session, voice: voice)
                    }
                    if model.session.isDemo, answered { DemoNote() }
                }
                .coordinateSpace(.named(Self.space))
            }
            .contentMargins(.horizontal, theme.spacing.sheetMargin, for: .scrollContent)
            .contentMargins(.top, topMargin, for: .scrollContent)
            .contentMargins(.bottom, theme.spacing.xxl, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: placement.isExpanded) { _, expanded in
                if !expanded { withAnimation(.snappy) { proxy.scrollTo("top", anchor: .top) } }
            }
            // "More" on a card: show that step's full text in the step list.
            .task(id: model.navigator.expandedRow) {
                guard let row = model.navigator.expandedRow else { return }
                try? await Task.sleep(for: theme.layout.sheetSettleDelay)
                withAnimation(.snappy) { proxy.scrollTo(StepListRows.scrollID(row), anchor: .top) }
                model.navigator.clearExpandedRow()
            }
        }
        .accessibilityIdentifier("answerSheet")
    }

    private func stop() { withAnimation(.snappy) { model.session.stop() } }
    private func close() { withAnimation(.snappy) { model.dismissSheet() } }
    private func selectBranch(_ i: Int?) { withAnimation(.snappy) { model.navigator.selectBranch(i) } }
}

#Preview("Sheet, medium") {
    AnswerContent(model: Fixtures.model(), voice: AskController(), placement: .sheet(.medium))
        .themeBackground(\.sheet).themed()
}
#Preview("Sheet, streaming") {
    AnswerContent(model: Fixtures.model(.streaming), voice: AskController(), placement: .sheet(.medium))
        .themeBackground(\.sheet).themed()
}
#Preview("Sheet, expanded") {
    AnswerContent(model: Fixtures.model(), voice: AskController(), placement: .sheet(.expanded))
        .themeBackground(\.sheet).themed()
}
#Preview("Branch") {
    AnswerContent(model: Fixtures.model(.branch), voice: AskController(), placement: .sheet(.medium))
        .themeBackground(\.sheet).themed()
}
#Preview("Inspector, AX5") {
    AnswerContent(model: Fixtures.model(), voice: AskController(), placement: .inspector)
        .themeBackground(\.sheet).themed().dynamicTypeSize(.accessibility5)
}
#Preview("Expanded, dark") {
    AnswerContent(model: Fixtures.model(), voice: AskController(), placement: .sheet(.expanded))
        .themeBackground(\.sheet).themed().preferredColorScheme(.dark)
}

private extension View {
    /// Keeps the layout (detent heights are measured from it) but hides content below the header
    /// in the collapsed sheet, so the detent edge never cuts through a half-visible card.
    func hiddenWhenCollapsed(_ collapsed: Bool) -> some View {
        opacity(collapsed ? 0 : 1)
            .allowsHitTesting(!collapsed)
            .accessibilityHidden(collapsed)
            .animation(.snappy, value: collapsed)
    }
}
