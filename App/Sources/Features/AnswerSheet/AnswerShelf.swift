import SwiftUI

/// Step cards + page dots (S5/S6).
struct AnswerShelf: View {
    var model: ViewerModel
    @Environment(\.theme) private var theme

    var body: some View {
        let items = model.navigator.cardItems
        if !items.isEmpty {
            VStack(spacing: theme.spacing.m) {
                StepCarousel(items: items, selection: Bindable(model.navigator).cardID, onMore: showMore)
                    // Fresh measurements (shelf height) per answer and per branch.
                    .id(ShelfKey(answer: model.session.answer?.id, branch: model.navigator.activeBranch))
                CardDots(count: items.count, index: items.firstIndex { $0.id == model.navigator.currentCard } ?? 0)
            }
        }
    }

    private struct ShelfKey: Hashable {
        var answer: UUID?
        var branch: Int?
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
