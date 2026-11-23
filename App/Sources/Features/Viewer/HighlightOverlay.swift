import SwiftUI

/// Chrome over the PDF for the current evidence (S6): the "Quote 1 of 2 ›" pager when a step cites
/// several passages, and a note whenever the spotlight isn't the whole quote ("See the diagram,
/// lower half", "Part of the passage highlighted", "Passage not found · showing the whole page"),
/// so a missing or partial spotlight is never silent. Glass, as floating controls over content.
///
/// Note and pager share one row when both fit; otherwise the pager sits on its own row above the
/// note (narrow phones, large text), so neither crowds the other. Only mounted when it has one of
/// them (`ViewerModel.highlightChrome`).
struct HighlightOverlay: View {
    var evidenceIndex: Int
    var evidenceCount: Int
    var note: String?
    var noteKind: HighlightNoteKind = .info
    var onNext: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.s) {
                    noteLabel
                    Spacer(minLength: 0)
                    pager
                }
                VStack(alignment: .trailing, spacing: theme.spacing.s) {
                    pager
                    noteLabel.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, theme.spacing.l)
    }

    @ViewBuilder private var noteLabel: some View {
        if let note {
            Label(note, systemImage: noteKind.symbol)
                .font(theme.font.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.s)
                .glassEffect(.regular, in: .rect(cornerRadius: theme.radius.note))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(note)
                .accessibilityIdentifier("highlightNote")
        }
    }

    @ViewBuilder private var pager: some View {
        if evidenceCount > 1 {
            Button(action: onNext) {
                Label("Quote \(evidenceIndex + 1) of \(evidenceCount)", systemImage: "chevron.forward")
                    .labelStyle(TrailingIconLabelStyle())
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .buttonStyle(.glass)
            .fixedSize()
            .accessibilityLabel("Quote \(evidenceIndex + 1) of \(evidenceCount)")
            .accessibilityHint("Shows the next quote for this step")
            .accessibilityIdentifier("evidencePager")
        }
    }
}

#Preview("States") {
    VStack(spacing: 16) {
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: nil) {}
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 1, note: "See the diagram, lower half") {}
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial) {}
        HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.notFoundNote, noteKind: .miss) {}
    }
    .padding(.vertical)
    .frame(maxHeight: .infinity)
    .background(Fixtures.pageBackdrop)
    .themed()
}

#Preview("iPhone SE width") {
    HighlightOverlay(evidenceIndex: 1, evidenceCount: 3, note: HighlightPlacer.notFoundNote, noteKind: .miss) {}
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .background(Fixtures.pageBackdrop)
        .themed()
}

#Preview("AX5, dark") {
    VStack(spacing: 16) {
        HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.notFoundNote, noteKind: .miss) {}
        HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial) {}
    }
    .frame(maxHeight: .infinity)
    .background(Fixtures.pageBackdrop)
    .themed()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
