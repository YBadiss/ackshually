import SwiftUI

/// The expanded part of the answer (S9): all steps, assumptions, "Was this right?".
struct FullAnswerSections: View {
    var model: ViewerModel
    /// On the sheet, picking a step drops back to the medium detent to show its card.
    var collapsesOnSelect: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            StepListRows(rows: model.stepRows, current: model.focusedRow, onSelect: select)
            if let a = model.answer?.assumptions, !a.isEmpty { AssumptionRows(assumptions: a) }
            if model.answer?.complete == true {
                GroupedSection(title: "Was this right?") {
                    FeedbackButtons(rating: model.currentRating, onRate: model.rate)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func select(_ i: Int) {
        model.selectRow(i)
        if collapsesOnSelect { withAnimation(.snappy) { model.detent = .medium } }
    }
}

#Preview {
    ScrollView { FullAnswerSections(model: Fixtures.model(), collapsesOnSelect: true).padding(.horizontal) }
        .themeBackground(\.sheet).themed()
}
#Preview("AX5, dark") {
    ScrollView { FullAnswerSections(model: Fixtures.model(), collapsesOnSelect: true).padding(.horizontal) }
        .themeBackground(\.sheet).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
