import SwiftUI

/// Between send and the first token (≈4–5 s on a full rulebook) the ask field becomes
/// "Reading the rulebook…" with the question and Stop. The sheet rises on the first token (S4).
struct WaitingBar: View {
    var question: String
    var onStop: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            ProgressView()
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("Reading the rulebook…").font(theme.font.waiting).foregroundStyle(theme.colors.label)
                Text(question).font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.circle.fill").labelStyle(.iconOnly).font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: theme.size.minTapTarget, minHeight: theme.size.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("stop")
        }
        .padding(.leading, theme.spacing.l).padding(.trailing, theme.spacing.xs)
        .padding(.vertical, theme.spacing.xs)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    WaitingBar(question: "Can I keep unused energy with a Battery?") {}
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Fixtures.pageBackdrop)
        .themed()
}

#Preview("AX5, dark") {
    WaitingBar(question: "Can I keep unused energy with a Battery?") {}
        .padding()
        .background(Fixtures.pageBackdrop)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
