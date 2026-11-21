import SwiftUI

/// Between send and the first token (≈4–5 s on a full rulebook): the ask bar becomes
/// "Reading the rulebook…" with Stop. The sheet rises on the first token (S4).
struct WaitingBar: View {
    var question: String
    var onStop: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            ProgressView().tint(theme.colors.accent)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("Reading the rulebook…").font(theme.font.question).foregroundStyle(theme.colors.ink)
                Text(question).font(theme.font.meta).foregroundStyle(theme.colors.muted).lineLimit(1)
            }
            Spacer(minLength: theme.spacing.s)
            OutlineButton(title: "Stop", systemImage: "stop.fill", action: onStop)
                .accessibilityIdentifier("stop")
        }
        .padding(.leading, theme.spacing.l).padding(.trailing, theme.spacing.s).padding(.vertical, theme.spacing.s)
        .background(theme.colors.card, in: RoundedRectangle(cornerRadius: theme.radius.field))
        .shadow(color: theme.colors.line, radius: 0, y: theme.size.hairline)
    }
}

#Preview {
    WaitingBar(question: "Can I keep unused energy with a Battery?") {}
        .padding()
        .themeBackground(\.background)
        .themed()
}
