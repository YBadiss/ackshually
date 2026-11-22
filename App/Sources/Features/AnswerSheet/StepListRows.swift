import SwiftUI

/// All steps of the main answer (S9): tap to jump back to that card.
struct StepListRows: View {
    var rows: [StepRow]
    var current: Int?
    var onSelect: (Int) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection(title: "Steps") {
            ForEach(rows) { row in
                Button { onSelect(row.index) } label: { label(row) }
                    .accessibilityAddTraits(current == row.index ? .isSelected : [])
                    .accessibilityIdentifier("stepRow-\(row.index)")
                    .id(Self.scrollID(row.index))
            }
        }
        .buttonStyle(.plain)
    }

    static func scrollID(_ index: Int) -> String { "stepRow-\(index)" }

    private func label(_ row: StepRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.l) {
            Text("\(row.index + 1)")
                .font(theme.font.row.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryLabel)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(row.title).font(theme.font.row).foregroundStyle(current == row.index ? theme.colors.tint : theme.colors.label)
                Text(row.text).font(theme.font.rowValue).foregroundStyle(theme.colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let p = StepCard.pageText(row.pages) {
                Text(p).font(theme.font.rowValue.monospacedDigit()).foregroundStyle(theme.colors.secondaryLabel)
            }
        }
        .contentShape(.rect)
    }
}
