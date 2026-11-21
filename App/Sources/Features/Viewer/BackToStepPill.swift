import SwiftUI

/// "⤺ Back to step N" (S8): appears once the user pinches/pans away from the evidence.
struct BackToStepPill: View {
    var step: Int
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text("⤺ Back to step \(step)")
                .font(theme.font.pill)
                .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
                .foregroundStyle(theme.colors.paper)
                .background(theme.colors.ink, in: Capsule())
                .shadow(color: theme.colors.shadow, radius: theme.spacing.s, y: theme.spacing.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("backToStep")
    }
}

#Preview {
    VStack(spacing: 12) {
        BackToStepPill(step: 2) {}
        BackToStepPill(step: 2) {}.dynamicTypeSize(.accessibility3)
    }
    .padding()
    .themed()
}
