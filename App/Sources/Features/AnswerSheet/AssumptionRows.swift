import SwiftUI

/// "Assumes" (S9).
struct AssumptionRows: View {
    var assumptions: [String]
    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection(title: "Assumes") {
            ForEach(assumptions, id: \.self) {
                Text($0).font(theme.font.row).foregroundStyle(theme.colors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
