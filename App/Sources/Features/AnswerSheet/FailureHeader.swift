import SwiftUI

/// Error state of the header: what happened and Try Again (the header's close button closes).
/// `onSettings` (a rejected access token or API key) adds Open Settings as the main action.
struct FailureHeader: View {
    var message: String
    var onRetry: () -> Void
    var onSettings: (() -> Void)?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Label("That didn't work", systemImage: "exclamationmark.triangle.fill")
                .font(theme.font.verdict)
                .foregroundStyle(theme.colors.label)
            Text(message)
                .font(theme.font.proof)
                .foregroundStyle(theme.colors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("failureMessage")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.m) { FailureActions(onRetry: onRetry, onSettings: onSettings) }
                VStack(alignment: .leading, spacing: theme.spacing.s) { FailureActions(onRetry: onRetry, onSettings: onSettings) }
            }
            .padding(.top, theme.spacing.xs)
        }
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: 32) {
        FailureHeader(message: Fixtures.tokenRejected, onRetry: {}, onSettings: {})
        FailureHeader(message: Fixtures.dailyLimit, onRetry: {})
    }
    .padding()
    .themeBackground(\.sheet)
    .themed()
}

#Preview("Dark, AX5") {
    ScrollView { FailureHeader(message: Fixtures.tokenRejected, onRetry: {}, onSettings: {}).padding() }
        .themeBackground(\.sheet)
        .themed()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
