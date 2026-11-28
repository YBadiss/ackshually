import SwiftUI

/// The whole answer in one scrolling column, wired to the injected `ViewerModel`. The sheet
/// reveals it top-down (collapsed → header, medium → + step cards, follow-up row and branches, large →
/// the cards unfold into the step list, + assumptions); the inspector shows all of it.
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
                        if listsSteps {
                            // The expanded sheet unfolds the cards into the full step list, in place.
                            StepListRows(rows: model.navigator.stepRows, current: model.navigator.focusedRow, onSelect: selectStep)
                        } else {
                            AnswerShelf(model: model)
                                // Edge to edge: the cards peek from the sheet's sides.
                                .padding(.horizontal, -theme.spacing.sheetMargin)
                                .revealed(!placement.isCollapsed)
                        }
                    }
                    // On the sheet, follow-up + thumbs in their own row under the steps, at every
                    // detent (the inspector has them in the full sections below). Shown, disabled,
                    // while streaming.
                    if model.session.canFollowUp || model.session.isBusy, placement != .inspector {
                        AnswerFooterRow(draft: Bindable(model.session).draft, voice: voice, rating: model.session.currentRating,
                                        onRate: model.session.rate, onSend: model.session.ask)
                            .disabled(!model.session.canFollowUp)
                            .revealed(!placement.isCollapsed)
                    }
                    if answered, !model.navigator.branchRows.isEmpty {
                        BranchRows(rows: model.navigator.branchRows, onSelect: selectBranch)
                            .revealed(!placement.isCollapsed)
                    }
                    // The medium detent ends here; what follows shows when expanded. The stack's
                    // spacing above this marker is the bottom margin of the medium detent. The sheet
                    // adds the home-indicator inset and the content draws under it, so what follows is
                    // only revealed when expanded instead of showing half-cut under the edge.
                    Color.clear.frame(height: 0)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: {
                            metrics.medium = $0 + topMargin
                            onMetrics(metrics)
                        }
                    if answered, placement == .inspector {
                        FullAnswerSections(model: model)
                    } else if answered, let a = model.session.answer?.assumptions, !a.isEmpty {
                        AssumptionRows(assumptions: a)
                            .revealed(placement.isExpanded)
                    }
                    if model.session.canFollowUp, placement == .inspector {
                        FollowUpSection(session: model.session, voice: voice)
                    }
                    if model.session.isDemo, answered { DemoNote().revealed(placement.isExpanded) }
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

    /// The expanded sheet shows the step list where the cards were (so nothing appears twice).
    private var listsSteps: Bool { answered && placement == .sheet(.expanded) }

    /// A step picked in the expanded list: back to medium, on its card.
    private func selectStep(_ i: Int) {
        model.navigator.selectRow(i)
        withAnimation(.snappy) { model.detent = .medium }
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
    /// Keeps the layout (detent heights are measured from it) but hides content past the detent the
    /// sheet rests on (below the header when collapsed, below the branch rows at medium), so the
    /// detent edge never cuts through a half-visible card or section. Opacity, hit testing and
    /// VoiceOver only, so the measurements don't change.
    func revealed(_ shown: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
            .animation(.snappy, value: shown)
    }
}
