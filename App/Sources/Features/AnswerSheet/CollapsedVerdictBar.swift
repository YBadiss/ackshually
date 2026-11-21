import SwiftUI
import AckshuallyCore

/// Collapsed sheet (S7): one-line verdict + "✓ p.14", page near full-screen above it.
struct CollapsedVerdictBar: View {
    var verdict: String
    var confidence: Confidence?
    var pages: [Int]
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            Text(verdict)
                .font(theme.font.question).foregroundStyle(theme.colors.ink)
                .lineLimit(1)
            Spacer(minLength: theme.spacing.s)
            if let confidence { ConfidenceChip(confidence: confidence, pages: pages, short: true).fixedSize() }
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.bottom, theme.spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to show the answer")
    }
}

#Preview {
    VStack {
        CollapsedVerdictBar(verdict: "Keep 2 energy on the Battery, discard 1.", confidence: .stated, pages: [4])
        CollapsedVerdictBar(verdict: "Probably yes; the rules don't say.", confidence: .notCovered, pages: [])
    }
    .padding(.vertical)
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    CollapsedVerdictBar(verdict: "Keep 2 energy on the Battery, discard 1.", confidence: .stated, pages: [4])
        .themeBackground(\.sheet)
        .themed()
        .dynamicTypeSize(.accessibility5)
}
