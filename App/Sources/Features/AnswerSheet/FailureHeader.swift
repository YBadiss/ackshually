import SwiftUI

/// Error state of the header: what happened and Try Again (the header's close button closes).
struct FailureHeader: View {
    var message: String
    var onRetry: () -> Void
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
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .padding(.top, theme.spacing.xs)
        }
    }
}

#Preview {
    FailureHeader(message: "The API key was rejected. Check it in Settings.", onRetry: {})
        .padding()
        .themeBackground(\.sheet)
        .themed()
}
