import SwiftUI

/// Wide screens (iPad, Mac, phone landscape): the whole answer in the trailing column beside the PDF
/// (`AdaptiveViewerLayout` sizes it).
struct AnswerInspector: View {
    var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        AnswerContent(model: model, voice: voice, placement: .inspector)
            .background(theme.colors.sheet, ignoresSafeAreaEdges: .all)
    }
}

#Preview("Inspector", traits: .fixedLayout(width: 1024, height: 768)) {
    ViewerPreview().themed().environment(\.horizontalSizeClass, .regular)
}
