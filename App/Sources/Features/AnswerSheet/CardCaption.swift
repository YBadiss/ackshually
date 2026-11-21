import SwiftUI

/// "General rule ………… p.3" (stacks at large text sizes).
struct CardCaption: View {
    var title: String
    var trailing: String?
    var systemImage: String?
    @Environment(\.theme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                titleView
                Spacer(minLength: theme.spacing.s)
                trailingView
            }
            VStack(alignment: .leading, spacing: theme.spacing.xxs) { titleView; trailingView }
        }
        .font(theme.font.cardCaption)
        .foregroundStyle(theme.colors.secondaryLabel)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var titleView: some View {
        if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }

    @ViewBuilder private var trailingView: some View {
        if let trailing { Text(trailing).monospacedDigit() }
    }
}
