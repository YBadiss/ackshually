import SwiftUI
import AckshuallyCore

/// Expanded sheet body (S9): all steps (tap to jump), assumptions, the other branches.
struct FullAnswerList: View {
    var rows: [StepRow]
    var current: Int?
    var assumptions: [String]
    var branches: [Branch]
    var onSelect: (Int) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionLabel("Steps")
            ForEach(rows) { row in
                Button { onSelect(row.index) } label: { rowView(row) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(current == row.index ? .isSelected : [])
            }
            if !assumptions.isEmpty {
                SectionLabel("Assumes")
                ForEach(assumptions, id: \.self) {
                    Text($0).font(theme.font.body).foregroundStyle(theme.colors.muted)
                }
            }
            if !branches.isEmpty {
                SectionLabel("Otherwise")
                ForEach(Array(branches.enumerated()), id: \.offset) { _, b in
                    (Text(b.condition + ": ").bold() + Text(b.verdict))
                        .font(theme.font.body).foregroundStyle(theme.colors.ink)
                }
            }
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func rowView(_ row: StepRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.m) {
            Text("\(row.index + 1)").font(theme.font.cardTitle).foregroundStyle(theme.colors.ink)
            Text(row.text).font(theme.font.body).foregroundStyle(theme.colors.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let p = StepCard.pageText(row.pages) {
                Text(p).font(theme.font.meta).foregroundStyle(theme.colors.muted)
            }
        }
        .padding(.horizontal, theme.spacing.m).padding(.vertical, theme.spacing.m)
        .background(theme.colors.card, in: RoundedRectangle(cornerRadius: theme.radius.row))
        .overlay(RoundedRectangle(cornerRadius: theme.radius.row)
            .strokeBorder(current == row.index ? theme.colors.accent : .clear, lineWidth: theme.size.focusRing))
        .contentShape(RoundedRectangle(cornerRadius: theme.radius.row))
    }
}

/// Small uppercase section label ("STEPS", "ASSUMES").
struct SectionLabel: View {
    var text: String
    @Environment(\.theme) private var theme
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).font(theme.font.section).tracking(0.5).foregroundStyle(theme.colors.muted)
            .padding(.top, theme.spacing.m).padding(.bottom, theme.spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ScrollView {
        FullAnswerList(rows: Fixtures.stepRows, current: 1, assumptions: Fixtures.answer.assumptions,
                       branches: Fixtures.answer.branches) { _ in }
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    ScrollView {
        FullAnswerList(rows: Fixtures.stepRows, current: 0, assumptions: Fixtures.answer.assumptions, branches: []) { _ in }
    }
    .themeBackground(\.sheet)
    .themed()
    .dynamicTypeSize(.accessibility5)
}
