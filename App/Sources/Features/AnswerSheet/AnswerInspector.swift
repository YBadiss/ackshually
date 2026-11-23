import SwiftUI

/// Wide screens (iPad, Mac, phone landscape): the whole answer in the standard inspector column.
struct AnswerInspector: View {
    var model: ViewerModel
    var voice: AskController
    var idealWidth: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        AnswerContent(model: model, voice: voice, placement: .inspector)
            .background(theme.colors.sheet, ignoresSafeAreaEdges: .all)
            .inspectorColumnWidth(min: theme.layout.inspectorWidthRange.lowerBound, ideal: idealWidth,
                                  max: theme.layout.inspectorWidthRange.upperBound)
    }
}

#Preview("Inspector", traits: .fixedLayout(width: 1024, height: 768)) {
    ViewerPreview().themed().environment(\.horizontalSizeClass, .regular)
}
