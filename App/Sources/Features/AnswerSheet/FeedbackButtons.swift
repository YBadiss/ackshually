import SwiftUI

/// Thumbs up / down (S6, S9). Tapping the selected one clears it.
struct FeedbackButtons: View {
    var rating: Bool?
    var onRate: (Bool) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xxl) {
            button(up: true)
            button(up: false)
        }
        .font(theme.font.feedback)
        .buttonStyle(.borderless)
    }

    private func button(up: Bool) -> some View {
        let on = rating == up
        let symbol = up ? "hand.thumbsup" : "hand.thumbsdown"
        return Button { onRate(up) } label: {
            Label(up ? "Good answer" : "Bad answer", systemImage: on ? symbol + ".fill" : symbol)
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: theme.size.minTapTarget, minHeight: theme.size.minTapTarget)
                .contentShape(.rect)
        }
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(up ? "thumbsUp" : "thumbsDown")
    }
}

#Preview {
    VStack(spacing: 16) {
        FeedbackButtons(rating: nil) { _ in }
        FeedbackButtons(rating: true) { _ in }
        FeedbackButtons(rating: false) { _ in }
    }
    .padding()
    .themeBackground(\.card)
    .themed()
}
