import SwiftUI

/// Text capped at `lineLimit` lines; when it doesn't fit, a "More" button follows it.
/// Truncation is measured (the full text's height at the same width vs. the shown height), so it
/// holds at every Dynamic Type size and width.
struct TruncatingText: View {
    var text: String
    var lineLimit: Int
    var font: Font
    var onMore: () -> Void
    @Environment(\.theme) private var theme
    @State private var shownHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0

    private var truncated: Bool { fullHeight > shownHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(text)
                .font(font)
                .foregroundStyle(theme.colors.label)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                .background(alignment: .topLeading) {
                    Text(text)
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("stepCardText")
            if truncated {
                Button("More", action: onMore)
                    .font(theme.font.cardCaption)
                    .buttonStyle(.borderless)
                    .frame(minHeight: theme.size.minTapTarget * 0.6)
                    .accessibilityHint("Shows the whole step")
                    .accessibilityIdentifier("cardMore")
            }
        }
    }
}

#Preview("Short and long") {
    VStack(alignment: .leading, spacing: 24) {
        TruncatingText(text: "Discard all unused energy at the end of your turn.", lineLimit: 4, font: .callout) {}
        TruncatingText(text: String(repeating: "A Battery keeps up to 2 unused energy instead of discarding them. ", count: 6),
                       lineLimit: 4, font: .callout) {}
    }
    .padding()
    .themeBackground(\.card)
    .themed()
}

#Preview("AX5") {
    TruncatingText(text: String(repeating: "A Battery keeps up to 2 unused energy. ", count: 5), lineLimit: 4, font: .callout) {}
        .padding()
        .themeBackground(\.card)
        .themed()
        .dynamicTypeSize(.accessibility5)
}
