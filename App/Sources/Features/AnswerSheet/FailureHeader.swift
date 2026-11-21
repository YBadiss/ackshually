import SwiftUI

/// Error state of the header: plain message, Try again, Close.
struct FailureHeader: View {
    var question: String
    var message: String
    var onRetry: () -> Void
    var onClose: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text(question).font(theme.font.restated).foregroundStyle(theme.colors.muted)
            Text("Hmm, that didn't work.").font(theme.font.question).foregroundStyle(theme.colors.ink)
            Text(message).font(theme.font.body).foregroundStyle(theme.colors.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: theme.spacing.m) {
                PrimaryButton(title: "Try again", action: onRetry)
                OutlineButton(title: "Close", action: onClose)
            }
            .padding(.top, theme.spacing.xs).padding(.bottom, theme.spacing.l)
        }
    }
}

#Preview {
    FailureHeader(question: "Can I keep energy?", message: "The API key was rejected. Check it in Settings.", onRetry: {}, onClose: {})
        .padding()
        .themed()
}
