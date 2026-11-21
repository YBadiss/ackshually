import SwiftUI

/// Keeps the demo provider discoverable without a label on the verdict.
struct DemoNote: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Label("Demo answer: scripted, no API call. Add a key in Settings.", systemImage: "theatermasks")
            .font(theme.font.footnote)
            .foregroundStyle(theme.colors.secondaryLabel)
            .padding(.horizontal, theme.spacing.xxl)
            .accessibilityIdentifier("demoNote")
    }
}

#Preview { DemoNote().padding(.vertical).themeBackground(\.sheet).themed() }
