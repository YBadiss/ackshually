import SwiftUI

/// Body of the loading card: a placeholder as tall as the tallest real card can be
/// (`layout.cardMaxLines` lines + the "More" row of `TruncatingText`), so the shelf, and the
/// sheet sized from it, don't grow while steps stream in.
struct LoadingCardBody: View {
    @Environment(\.theme) private var theme

    private static let text = String(repeating: "Unused energy is discarded at the end of your turn, as the rules say. ", count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(Self.text)
                .font(theme.font.cardBody)
                .lineLimit(theme.layout.cardMaxLines, reservesSpace: true)
            Text("More")
                .font(theme.font.cardCaption)
                .frame(minHeight: theme.size.minTapTarget * 0.6)
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

#Preview("Default") {
    LoadingCardBody().padding().themeBackground(\.card).themed()
}
#Preview("AX5, dark") {
    LoadingCardBody().padding().themeBackground(\.card).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
