import SwiftUI

/// Chrome over the PDF for the current evidence (S6): the "1 of 2 ›" pager when a step cites
/// several passages, and a note when there is no word highlight ("See the diagram, lower half").
/// Glass, as floating controls over content.
struct HighlightOverlay: View {
    var evidenceIndex: Int
    var evidenceCount: Int
    var note: String?
    var onNext: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: theme.spacing.s) {
                if let note {
                    Label(note, systemImage: "doc.text.magnifyingglass")
                        .font(theme.font.footnote)
                        .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
                        .glassEffect(.regular, in: .capsule)
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
        HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: "Showing the whole page") {}
    }
    .padding(.vertical)
    .frame(maxHeight: .infinity)
    .background(Fixtures.pageBackdrop)
    .themed()
}

#Preview("AX5, dark") {
    HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: "Showing the whole page") {}
        .frame(maxHeight: .infinity)
        .background(Fixtures.pageBackdrop)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
