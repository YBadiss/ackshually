import SwiftUI

// Composites that wire the leaf components to the injected `ViewerModel`.
// The sheet (phones) and the side panel (wide screens) are built from these.

/// Header bound to the model's actions.
struct BoundAnswerHeader: View {
    var model: ViewerModel

    var body: some View {
        if let h = model.header {
            AnswerHeader(content: h,
                         onStop: { withAnimation(.snappy) { model.stop() } },
                         onBranch: { i in withAnimation(.snappy) { model.selectBranch(i) } },
                         onRetry: { model.retry() },
                         onClose: { withAnimation(.snappy) { model.dismissSheet() } })
        }
    }
}

/// Carousel + dots, and the follow-up field under the last card (S5/S6).
struct BoundStepCards: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    /// Side panel shows the follow-up field always (no detents there).
    var alwaysShowFollowUp = false
    @Environment(\.theme) private var theme

    var body: some View {
        let items = model.cardItems
        if model.header?.state == .answered, !items.isEmpty {
            VStack(spacing: theme.spacing.m) {
                StepCarousel(items: items, selection: $model.cardID, onRate: { model.rate($0) })
                CardDots(count: items.count, index: items.firstIndex { $0.id == model.currentCard } ?? 0)
                if alwaysShowFollowUp ? model.canFollowUp : model.currentCard == .result {
                    FollowUpField(model: model, voice: voice)
                }
            }
        }
    }
}

struct FollowUpField: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        AskBar(text: $model.draft, voice: voice, placeholder: "Follow-up question…", compact: true) { model.ask($0) }
            .padding(.horizontal, theme.spacing.xl)
    }
}

/// Medium detent (S5): header + cards.
struct AnswerMediumContent: View {
    var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BoundAnswerHeader(model: model)
            BoundStepCards(model: model, voice: voice)
        }
        .padding(.bottom, theme.spacing.l)
    }
}

/// Collapsed detent (S7).
struct AnswerCollapsedContent: View {
    var model: ViewerModel

    var body: some View {
        CollapsedVerdictBar(verdict: model.answer?.verdict ?? model.answer?.restated ?? "Reading the rulebook…",
                            confidence: model.answer?.confidence, pages: model.collapsedPages)
    }
}

/// Expanded detent (S9): header, all steps (tap → jump back to the cards), assumptions.
struct AnswerExpandedContent: View {
    var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                BoundAnswerHeader(model: model)
                if model.header?.state == .answered { list }
                if model.canFollowUp { FollowUpField(model: model, voice: voice) }
            }
            .padding(.bottom, theme.spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var list: some View {
        FullAnswerList(rows: model.stepRows, current: model.focusedStepNumber.map { $0 - 1 },
                       assumptions: model.answer?.assumptions ?? [], branches: model.answer?.branches ?? []) { i in
            model.selectStep(i)
            withAnimation(.snappy) { model.detent = .medium }
        }
    }
}

/// Wide screens: the whole answer in a side column beside the PDF.
struct AnswerSidePanel: View {
    var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                HStack {
                    Spacer()
                    Button { withAnimation(.snappy) { model.dismissSheet() } } label: {
                        Image(systemName: "xmark").font(theme.font.icon).foregroundStyle(theme.colors.muted)
                    }
                    .accessibilityLabel("Close answer")
                }
                .padding(.horizontal, theme.spacing.xl)
                BoundAnswerHeader(model: model)
                BoundStepCards(model: model, voice: voice, alwaysShowFollowUp: true)
                if model.header?.state == .answered {
                    FullAnswerList(rows: model.stepRows, current: model.focusedStepNumber.map { $0 - 1 },
                                   assumptions: model.answer?.assumptions ?? [], branches: model.answer?.branches ?? []) {
                        model.selectStep($0)
                    }
                }
            }
            .padding(.vertical, theme.spacing.l)
        }
        .scrollIndicators(.hidden)
        .themeBackground(\.sheet)
    }
}

#Preview("Medium") {
    AnswerMediumContent(model: Fixtures.model(), voice: AskController()).themeBackground(\.sheet).themed()
}
#Preview("Medium, streaming") {
    AnswerMediumContent(model: Fixtures.model(.streaming), voice: AskController()).themeBackground(\.sheet).themed()
}
#Preview("Expanded") {
    AnswerExpandedContent(model: Fixtures.model(), voice: AskController()).themeBackground(\.sheet).themed()
}
#Preview("Side panel") {
    AnswerSidePanel(model: Fixtures.model(), voice: AskController()).frame(width: 380).themed()
}
