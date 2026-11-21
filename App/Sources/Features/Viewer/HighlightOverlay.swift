import SwiftUI

/// Chrome drawn over the PDF for the current evidence (S6): the "1 of 2 ›" pager when a step
/// cites several passages, and a note when there is no word highlight ("See the diagram, lower half").
struct HighlightOverlay: View {
    var evidenceIndex: Int
    var evidenceCount: Int
    var note: String?
    var onNext: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            if let note {
                Text(note)
                    .font(theme.font.chip)
                    .padding(.horizontal, theme.spacing.m).padding(.vertical, theme.spacing.xs)
                    .foregroundStyle(theme.colors.ink)
                    .background(theme.colors.card.opacity(0.95), in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.colors.line))
            }
            Spacer(minLength: 0)
            if evidenceCount > 1 {
                Button(action: onNext) {
                    Text("\(evidenceIndex + 1) of \(evidenceCount) ›")
                        .font(theme.font.pill)
                        .padding(.horizontal, theme.spacing.m).padding(.vertical, theme.spacing.xs)
                        .foregroundStyle(theme.colors.paper)
                        .background(theme.colors.ink.opacity(0.85), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Passage \(evidenceIndex + 1) of \(evidenceCount). Next passage")
                .accessibilityIdentifier("evidencePager")
            }
        }
        .padding(.horizontal, theme.spacing.l)
    }
}

#Preview {
    VStack(spacing: 16) {
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: nil) {}
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 1, note: "See the diagram, lower half") {}
        HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: "Showing the whole page") {}
    }
    .padding(.vertical)
    .themeBackground(\.paper)
    .themed()
}
