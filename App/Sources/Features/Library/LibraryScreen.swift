import SwiftUI

/// Root of the app (S1 · My Games): the list of imported rulebooks in a `NavigationStack`;
/// a row pushes the viewer, whose Back returns here. The same stack on every size: on wide
/// screens the viewer already uses a trailing inspector column for the answer, so a
/// sidebar for the list would leave the PDF a third of the window (see m2-notes, My Games).
struct LibraryScreen: View {
    @Bindable var library: LibraryModel
    var voice: AskController
    @State private var importing = false
    @State private var settings = false
    @State private var windowSize = CGSize.zero

    var body: some View {
        NavigationStack(path: $library.navigationPath) {
            content
                .navigationTitle("My Games")
                .toolbar {
                    LibraryToolbar(onAdd: { importing = true }, onSettings: { settings = true })
                }
                .themeBackground(\.groupedBackground)
                .navigationDestination(for: GameRoute.self) { route in
                    ViewerScreen(model: library.session(for: route), voice: voice, windowSize: windowSize)
                }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { library.importPicked(url) }
        }
        .sheet(isPresented: $settings) {
            SettingsSheet { settings = false }
                .themed()
        }
    }

    @ViewBuilder private var content: some View {
        if !library.isLoaded {
            Color.clear
        } else if library.games.isEmpty {
            EmptyLibraryView(error: library.error, onAdd: { importing = true }, onSample: { library.addSample() })
        } else {
            GameList(games: library.games, covers: library.covers,
                     loadCover: { await library.loadCover(for: $0, pixelWidth: $1, scale: $2) },
                     onDelete: { library.delete($0) })
                .alert("Couldn't Open the Rulebook", item: $library.error) { _ in } message: { Text($0) }
        }
    }
}

#Preview("Games") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed() }
#Preview("Empty") { LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController()).themed() }
#Preview("Empty, dark") {
    LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController()).themed().preferredColorScheme(.dark)
}
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed()
}
#Preview("Landscape", traits: .landscapeLeft) { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed() }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().environment(\.horizontalSizeClass, .regular)
}
#Preview("AX5") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()).themed().preferredColorScheme(.dark) }
