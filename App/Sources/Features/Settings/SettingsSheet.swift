import SwiftUI

/// Settings bound to the app's credentials and settings (`AppDependencies`, from the environment).
struct SettingsSheet: View {
    var onDone: () -> Void
    @Environment(\.dependencies) private var dependencies
    @Environment(LibraryModel.self) private var library: LibraryModel?

    // The model built here is only kept the first time (`@State` below); later ones are dropped. The sheet's
    // body rarely re-runs (environment changes), and building one only reads the credentials.
    var body: some View {
        SettingsSheetContent(model: SettingsModel(credentials: dependencies.credentials, settings: dependencies.settings),
                             gameCount: library?.games.count ?? 0, onRemoveAllGames: { library?.removeAllGames() },
                             onDone: onDone)
    }
}

private struct SettingsSheetContent: View {
    /// Seeded once per presentation (later inits of this view are discarded).
    @State private var model: SettingsModel
    var gameCount: Int
    var onRemoveAllGames: () -> Void
    var onDone: () -> Void

    init(model: SettingsModel, gameCount: Int, onRemoveAllGames: @escaping () -> Void, onDone: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.gameCount = gameCount
        self.onRemoveAllGames = onRemoveAllGames
        self.onDone = onDone
    }

    var body: some View {
        @Bindable var model = model
        SettingsView(status: model.status, demo: $model.demoAnswers,
                     onSave: { model.save($0, for: $1) }, onRemove: { model.save(nil, for: $0) }, onDone: onDone,
                     gameCount: gameCount, onRemoveAllGames: onRemoveAllGames)
    }
}

#Preview("Nothing set up") { SettingsSheet {}.themed() }
#Preview("Bundled token, dark") {
    SettingsSheet {}
        .environment(\.dependencies, .inMemory(credentials: InMemoryCredentials(bundledToken: "fake")))
        .themed().preferredColorScheme(.dark)
}
