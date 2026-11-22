import SwiftUI

/// Step cards + page dots (S5/S6).
struct AnswerShelf: View {
    @Bindable var model: ViewerModel
    @Environment(\.theme) private var theme

    var body: some View {
        let items = model.cardItems
        if !items.isEmpty {
            VStack(spacing: theme.spacing.m) {
                StepCarousel(items: items, selection: $model.cardID, onMore: showMore)
                CardDots(count: items.count, index: items.firstIndex { $0.id == model.currentCard } ?? 0)
            }
        }
    }

    private func showMore(_ card: CardID) {
        withAnimation(.snappy) { model.showMore(card) }
    }
}

#Preview("Step 1") {
    AnswerShelf(model: Fixtures.model())
        .frame(maxHeight: .infinity).themeBackground(\.sheet).themed()
}
#Preview("AX5, dark") {
    AnswerShelf(model: Fixtures.model())
        .frame(maxHeight: .infinity).themeBackground(\.sheet).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
