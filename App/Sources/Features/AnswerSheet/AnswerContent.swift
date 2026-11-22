import SwiftUI

/// The whole answer in one scrolling column, wired to the injected `ViewerModel`. The sheet
/// reveals it top-down (collapsed → header, medium → + step cards and branches, large → + steps,
/// assumptions, feedback, follow-up); the inspector shows all of it.
struct AnswerContent: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    var placement: AnswerPlacement
    var onMetrics: (AnswerMetrics) -> Void = { _ in }
    @Environment(\.theme) private var theme
    @State private var metrics = AnswerMetrics()

    private nonisolated static let space = "answerContent"
    private var answered: Bool { model.header?.state == .answered }
    /// A rejected credential: the error header offers Settings.
    private var settingsAction: (() -> Void)? {
        guard model.failureOpensSettings else { return nil }
        return { model.requestSettings() }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    if let h = model.header {
                        AnswerHeader(content: h, showsQuestion: placement.isExpanded,
                                     onStop: stop, onRetry: model.retry,
                                     onSettings: settingsAction, onClose: close)
                            .padding(.horizontal, theme.spacing.xl)
                            .id("top")
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).maxY } action: {
                                metrics.collapsed = $0
                            }
                    }
                    if answered {
                        AnswerShelf(model: model)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    // Sheet below large: follow-up + thumbs in their own row (expanded / inspector
                    // have them in the full sections below).
                    if model.canFollowUp, !placement.isExpanded {
                        AnswerFooterRow(draft: $model.draft, voice: voice, rating: model.currentRating,
                                        onRate: model.rate, onSend: model.ask)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    if answered, !model.branchRows.isEmpty {
                        BranchRows(rows: model.branchRows, onSelect: selectBranch)
                            .padding(.horizontal, theme.spacing.l)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    // The medium detent ends here; what follows shows when expanded.
                    Color.clear.frame(height: 0)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: {
                            metrics.medium = $0 - theme.spacing.xl
                        }
                    if answered {
                        FullAnswerSections(model: model, collapsesOnSelect: placement != .inspector)
                            .hiddenWhenCollapsed(placement.isCollapsed)
                    }
                    if model.canFollowUp, placement.isExpanded {
                        FollowUpSection(model: model, voice: voice)
                    }
                    if model.isDemo, answered { DemoNote() }
                }
                .padding(.top, theme.spacing.xl)
                .padding(.bottom, theme.spacing.xxl)
                .coordinateSpace(.named(Self.space))
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: placement.isExpanded) { _, expanded in
                if !expanded { withAnimation(.snappy) { proxy.scrollTo("top", anchor: .top) } }
            }
            // "More" on a card: show that step's full text in the step list.
            .task(id: model.expandedRow) {
                guard let row = model.expandedRow else { return }
                try? await Task.sleep(for: theme.layout.sheetSettleDelay)
                withAnimation(.snappy) { proxy.scrollTo(StepListRows.scrollID(row), anchor: .top) }
                model.clearExpandedRow()
            }
        }
        .onChange(of: metrics, initial: true) { _, m in onMetrics(m) }
        .accessibilityIdentifier("answerSheet")
    }

    private func stop() { withAnimation(.snappy) { model.stop() } }
    private func close() { withAnimation(.snappy) { model.dismissSheet() } }
    private func selectBranch(_ i: Int?) { withAnimation(.snappy) { model.selectBranch(i) } }
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
