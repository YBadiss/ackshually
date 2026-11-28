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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("assumptions")
    }
}

#Preview { AssumptionRows(assumptions: Fixtures.answer.assumptions).padding().themeBackground(\.sheet).themed() }
#Preview("Several, AX5, dark") {
    ScrollView {
        AssumptionRows(assumptions: Fixtures.answer.assumptions + ["You are playing the base game, without expansions."]).padding()
    }
    .themeBackground(\.sheet).themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
