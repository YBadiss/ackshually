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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    if let h = model.header {
                        AnswerHeader(content: h, showsQuestion: placement.isExpanded,
                                     onStop: stop, onRetry: model.retry, onClose: close)
                            .padding(.horizontal, theme.spacing.xl)
                            .id("top")
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).maxY } action: {
                                metrics.collapsed = $0
                            }
                    }
                    if answered {
                        AnswerShelf(model: model, voice: voice, showsFollowUp: !placement.isExpanded)
                    }
                    if answered, !model.branchRows.isEmpty {
                        BranchRows(rows: model.branchRows, onSelect: selectBranch)
                            .padding(.horizontal, theme.spacing.l)
                    }
                    // The medium detent ends here; what follows shows when expanded.
                    Color.clear.frame(height: 0)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: {
                            metrics.medium = $0 - theme.spacing.xl
                        }
                    if answered {
                        FullAnswerSections(model: model, collapsesOnSelect: placement != .inspector)
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
