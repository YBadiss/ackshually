import SwiftUI

/// Outlined secondary button ("■ Stop", "Close").
struct OutlineButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
            }
            .font(theme.font.pill)
            .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
            .foregroundStyle(theme.colors.ink)
            .overlay(RoundedRectangle(cornerRadius: theme.radius.button).strokeBorder(theme.colors.line))
            .contentShape(RoundedRectangle(cornerRadius: theme.radius.button))
        }
        .buttonStyle(.plain)
    }
}

/// Filled primary button ("Try again").
struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.font.pill)
                .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
                .foregroundStyle(theme.colors.accentInk)
                .background(theme.colors.accent, in: RoundedRectangle(cornerRadius: theme.radius.button))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        OutlineButton(title: "Stop", systemImage: "stop.fill") {}
        PrimaryButton(title: "Try again") {}
    }
    .padding()
    .themed()
}
