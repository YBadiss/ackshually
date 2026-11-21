import SwiftUI

/// Step cards + page dots (S5/S6) and, on the last card, the follow-up field right under them.
struct AnswerShelf: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    /// Sheet below the large detent: the follow-up field sits under the result card.
    var showsFollowUp: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let items = model.cardItems
        if !items.isEmpty {
            VStack(spacing: theme.spacing.m) {
                StepCarousel(items: items, selection: $model.cardID, onRate: model.rate)
                CardDots(count: items.count, index: items.firstIndex { $0.id == model.currentCard } ?? 0)
                if showsFollowUp, model.currentCard == .result, model.canFollowUp {
                    AskField(text: $model.draft, voice: voice, placeholder: "Ask a follow-up", style: .inline, onSend: model.ask)
                        .padding(.horizontal, theme.spacing.xl)
                        .padding(.top, theme.spacing.xs)
                }
            }
        }
    }
}

#Preview("Step 1") {
    AnswerShelf(model: Fixtures.model(), voice: AskController(), showsFollowUp: true)
        .frame(maxHeight: .infinity).themeBackground(\.sheet).themed()
}
#Preview("AX5, dark") {
    AnswerShelf(model: Fixtures.model(), voice: AskController(), showsFollowUp: true)
        .frame(maxHeight: .infinity).themeBackground(\.sheet).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
