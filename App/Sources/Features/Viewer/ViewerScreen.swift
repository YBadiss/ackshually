import SwiftUI

/// The viewer, pushed from My Games (Back returns to the list): navigation bar with the ⋯ menu,
/// the adaptive viewer, and the viewer's dialogs. Owns no answer logic; that's the game's `ViewerModel`
/// (nil once the game was deleted).
struct ViewerScreen: View {
    var model: ViewerModel?
    var voice: AskController
    /// The whole window, measured by the root stack (outside the inspector, so opening it can't
    /// flip the layout).
    var windowSize: CGSize
    /// A library game's title with its ticked add-ons ("Root · Riverfolk"): shown as a button that opens
    /// "Playing with" (S13). nil for a file opened outside the library (plain title).
    var title: String? = nil

    var body: some View {
        if let model {
            LoadedViewerScreen(model: model, voice: voice, windowSize: windowSize, title: title)
        } else {
            ContentUnavailableView("Rulebook Removed", systemImage: "book.closed")
                .navigationBarTitleDisplayMode(.inline)
                .viewerChrome()
        }
    }
}

private struct LoadedViewerScreen: View {
    var model: ViewerModel
    var voice: AskController
    var windowSize: CGSize
    var title: String?

    var body: some View {
        AdaptiveViewerLayout(model: model, voice: voice, document: model.rulebook.pdf, windowSize: windowSize)
            .navigationTitle(model.rulebook.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .principal) {
                        GameTitleButton(title: title) { model.presentation.playingWith = true }
                    }
                }
                if model.rulebook.contents.isJoined {
                    BookSwitcher(parts: model.rulebook.contents.parts) { model.showBook($0) }
                }
            }
            .toolbar {
                ViewerMenu(hasAnswer: model.session.answer != nil, answerShown: model.sheetVisible, isDemo: model.showsDemoNote,
                           onShowAnswer: { withAnimation(.snappy) { model.showSheet() } },
                           onDetails: { model.presentation.answerDetails = true })
            }
            .viewerChrome()
            .viewerDialogs(model: model, active: !model.presentation.answerSheetPresented)
    }
}

#Preview { NavigationStack { ViewerScreen(model: Fixtures.model(), voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }.themed() }
#Preview("Idle") { NavigationStack { ViewerScreen(model: Fixtures.model(.idle), voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }.themed() }
#Preview("Two books") {
    NavigationStack {
        ViewerScreen(model: Fixtures.setModel(card: 1), voice: AskController(), windowSize: CGSize(width: 402, height: 874),
                     title: "Power Plant Rush · Solar Expansion")
    }
    .environment(PlayingWithFixtures.library())
    .themed()
}
#Preview("Removed, dark") {
    NavigationStack { ViewerScreen(model: nil, voice: AskController(), windowSize: CGSize(width: 402, height: 874)) }
        .themed().preferredColorScheme(.dark)
}
