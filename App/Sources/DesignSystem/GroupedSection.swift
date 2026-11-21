import SwiftUI

/// An inset-grouped section (Settings style) for content that lives in a `ScrollView` next to
/// the step shelf: header, rounded group of rows with inset separators, optional footer.
/// Used on the answer sheet instead of a `List` so the sheet can measure its detents in one
/// coordinate space and the shelf's peeking cards can span the full width.
struct GroupedSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            if let title {
                Text(title.uppercased())
                    .font(theme.font.sectionHeader)
                    .foregroundStyle(theme.colors.secondaryLabel)
                    .padding(.horizontal, theme.spacing.xl)
                    .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Rectangle().fill(theme.colors.separator)
                                .frame(height: 1 / displayScale)
                                .padding(.leading, theme.spacing.xl)
                        }
                        row
                            .padding(.horizontal, theme.spacing.xl)
                            .padding(.vertical, theme.spacing.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(theme.colors.card, in: .rect(cornerRadius: theme.radius.group))
            }
            if let footer {
                Text(footer)
                    .font(theme.font.footnote)
                    .foregroundStyle(theme.colors.secondaryLabel)
                    .padding(.horizontal, theme.spacing.xl)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            GroupedSection(title: "If…") {
                ValueRow(title: "Without a Battery", systemImage: "arrow.triangle.branch", value: "Discard all 3.")
                ValueRow(title: "Two Batteries", systemImage: "arrow.triangle.branch", value: "Keep all 3.", accessory: .checkmark)
            }
            GroupedSection(title: "Assumes", footer: "Demo answer: scripted, no API call.") {
                Text("The Battery is already one of your plants.")
            }
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5, dark") {
    ScrollView {
        GroupedSection(title: "If…") {
            ValueRow(title: "Without a Battery", systemImage: "arrow.triangle.branch", value: "Discard all 3.")
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
