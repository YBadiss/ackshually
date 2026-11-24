import SwiftUI

/// A picked file waiting for the suggestion (S14, "Sorting…").
struct SortingRow: View {
    var title: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            GameCover(image: nil)
            Text(title)
                .font(theme.font.row)
                .foregroundStyle(theme.colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("Sorting")
    }
}

#Preview { List { SortingRow(title: "dune-imperium.pdf"); SortingRow(title: "A very long file name for a rulebook.pdf") }.themed() }
