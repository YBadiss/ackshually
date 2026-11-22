import SwiftUI

/// Root screen (M2 opens straight into the last PDF; S1 is M3): navigation bar with the ⋯ menu,
/// the adaptive viewer, and the app dialogs. Owns no answer logic; that's `ViewerModel`.
struct ViewerScreen: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    @State private var presentation = ViewerPresentation()
    @State private var windowSize = CGSize.zero

    var body: some View {
        NavigationStack {
            Group {
                if let rb = model.rulebook {
                    AdaptiveViewerLayout(model: model, voice: voice, document: rb.pdf, presentation: presentation, windowSize: windowSize)
                } else {
                    EmptyLibraryView(error: model.openError, onOpen: { presentation.importing = true }, onSample: { model.openSample() })
                }
            }
            .navigationTitle(model.rulebook?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ViewerMenu(hasAnswer: model.answer != nil, answerShown: model.sheetVisible,
                           isDemo: model.isDemo || CredentialStore.route == nil,
                           onOpen: { presentation.importing = true },
                           onSample: { model.openSample() },
                           onShowAnswer: { withAnimation(.snappy) { model.showSheet() } },
                           onDetails: { presentation.answerDetails = true },
                           onSettings: { presentation.settings = true })
            }
            .viewerChrome()
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
        .viewerDialogs(presentation, model: model, active: !presentation.answerSheetPresented)
        .onChange(of: model.settingsRequested) { _, requested in
            guard requested else { return }
            model.settingsRequested = false
            presentation.settings = true
        }
    }
}

#Preview { ViewerScreen(model: Fixtures.model(), voice: AskController()).themed() }
#Preview("Empty") { ViewerScreen(model: ViewerModel(), voice: AskController()).themed() }
#Preview("Empty, dark") { ViewerScreen(model: ViewerModel(), voice: AskController()).themed().preferredColorScheme(.dark) }
