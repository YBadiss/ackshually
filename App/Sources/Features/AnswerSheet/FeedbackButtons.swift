import SwiftUI

/// 👍/👎 on the last card (S6). Tapping the selected one clears it.
struct FeedbackButtons: View {
    var rating: Bool?
    var onRate: (Bool) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            button("👍", up: true, label: "Good answer")
            button("👎", up: false, label: "Bad answer")
        }
    }

    private func button(_ emoji: String, up: Bool, label: String) -> some View {
        let on = rating == up
        return Button { onRate(up) } label: {
            Text(emoji).font(theme.font.emoji)
                .frame(maxWidth: .infinity).padding(.vertical, theme.spacing.xs)
                .background(on ? theme.colors.warningBG : .clear, in: RoundedRectangle(cornerRadius: theme.radius.button))
                .overlay(RoundedRectangle(cornerRadius: theme.radius.button)
                    .strokeBorder(on ? theme.colors.accent : theme.colors.line, lineWidth: on ? theme.size.focusRing : theme.size.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

#Preview {
    VStack {
        FeedbackButtons(rating: nil) { _ in }
        FeedbackButtons(rating: true) { _ in }
        FeedbackButtons(rating: false) { _ in }
    }
    .padding()
    .themeBackground(\.card)
    .themed()
}
