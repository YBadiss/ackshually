import SwiftUI

/// Chrome over the PDF for the current evidence (S6): the "1 of 2 ›" pager when a step cites
/// several passages, and a note whenever nothing is spotlit ("See the diagram, lower half",
/// "Passage not found · showing the whole page"), so a missing spotlight is never silent.
/// Glass, as floating controls over content.
struct HighlightOverlay: View {
    var evidenceIndex: Int
    var evidenceCount: Int
    var note: String?
    /// The quote wasn't found or placed (vs. a figure note): warning symbol.
    var isMiss = false
    var onNext: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: theme.spacing.s) {
                if let note {
                    Label(note, systemImage: isMiss ? "exclamationmark.magnifyingglass" : "doc.text.magnifyingglass")
                        .font(theme.font.footnote)
                        .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
                        .glassEffect(.regular, in: .capsule)
                        .accessibilityIdentifier("highlightNote")
                }
                Spacer(minLength: 0)
                if evidenceCount > 1 {
                    Button(action: onNext) {
                        Label("\(evidenceIndex + 1) of \(evidenceCount)", systemImage: "chevron.forward")
                            .labelStyle(TrailingIconLabelStyle())
                            .monospacedDigit()
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Passage \(evidenceIndex + 1) of \(evidenceCount). Next passage")
                    .accessibilityIdentifier("evidencePager")
                }
            }
        }
        .padding(.horizontal, theme.spacing.l)
    }
}

#Preview {
    VStack(spacing: 16) {
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: nil) {}
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 1, note: "See the diagram, lower half") {}
        HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.notFoundNote, isMiss: true) {}
    }
    .padding(.vertical)
    .frame(maxHeight: .infinity)
    .background(Fixtures.pageBackdrop)
    .themed()
}

#Preview("AX5, dark") {
    HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.notFoundNote, isMiss: true) {}
        .frame(maxHeight: .infinity)
        .background(Fixtures.pageBackdrop)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
