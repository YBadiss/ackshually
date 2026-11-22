import SwiftUI

/// The viewer, pushed from My Games (Back returns to the list): navigation bar with the ⋯ menu,
/// the adaptive viewer, and the viewer's dialogs. Owns no answer logic; that's `ViewerModel`.
struct ViewerScreen: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    /// The whole window, measured by the root stack (outside the inspector, so opening it can't
    /// flip the layout).
    var windowSize: CGSize
    @State private var presentation = ViewerPresentation()

    var body: some View {
        Group {
            if let rb = model.rulebook {
                AdaptiveViewerLayout(model: model, voice: voice, document: rb.pdf, presentation: presentation, windowSize: windowSize)
            } else {
                ContentUnavailableView("Rulebook Removed", systemImage: "book.closed")
            }
        }
        .navigationTitle(model.rulebook?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ViewerMenu(hasAnswer: model.answer != nil, answerShown: model.sheetVisible,
                       isDemo: model.isDemo || CredentialStore.route == nil,
                       onShowAnswer: { withAnimation(.snappy) { model.showSheet() } },
                       onDetails: { presentation.answerDetails = true })
        }
        .viewerChrome()
        .viewerDialogs(presentation, model: model, active: !presentation.answerSheetPresented)
        .onChange(of: model.settingsRequested, initial: true) { _, requested in
            guard requested else { return }
            model.settingsRequested = false
            presentation.settings = true
        }
    }
}

#Preview { NavigationStack { ViewerScreen(model: Fixtures.model(), voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }.themed() }
#Preview("Idle") { NavigationStack { ViewerScreen(model: Fixtures.model(.idle), voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }.themed() }
#Preview("Removed, dark") {
    NavigationStack { ViewerScreen(model: ViewerModel(), voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }
        .themed().preferredColorScheme(.dark)
}
