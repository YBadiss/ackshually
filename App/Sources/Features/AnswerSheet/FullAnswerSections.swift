import SwiftUI

/// The rest of the answer in the inspector (wide screens): all steps, assumptions, "Was this right?".
/// The sheet shows its own arrangement (`AnswerContent`).
struct FullAnswerSections: View {
    var model: ViewerModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            StepListRows(rows: model.navigator.stepRows, current: model.navigator.focusedRow, onSelect: model.navigator.selectRow)
            if let a = model.session.answer?.assumptions, !a.isEmpty { AssumptionRows(assumptions: a) }
            if model.session.answer?.complete == true {
                GroupedSection(title: "Was this right?") {
                    FeedbackButtons(rating: model.session.currentRating, onRate: model.session.rate)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    ScrollView { FullAnswerSections(model: Fixtures.model()).padding(.horizontal) }
        .themeBackground(\.sheet).themed()
}
#Preview("AX5, dark") {
    ScrollView { FullAnswerSections(model: Fixtures.model()).padding(.horizontal) }
        .themeBackground(\.sheet).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
