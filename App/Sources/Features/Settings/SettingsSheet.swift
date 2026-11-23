import SwiftUI

/// Settings bound to the app's credentials and settings (`AppDependencies`, from the environment).
struct SettingsSheet: View {
    var onDone: () -> Void
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        SettingsSheetContent(model: SettingsModel(credentials: dependencies.credentials, settings: dependencies.settings),
                             onDone: onDone)
    }
}

private struct SettingsSheetContent: View {
    /// Seeded once per presentation (later inits of this view are discarded).
    @State private var model: SettingsModel
    var onDone: () -> Void

    init(model: SettingsModel, onDone: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onDone = onDone
    }

    var body: some View {
        @Bindable var model = model
        SettingsView(status: model.status, demo: $model.demoAnswers,
                     onSave: { model.save($0, for: $1) }, onRemove: { model.save(nil, for: $0) }, onDone: onDone)
    }
}

#Preview("Nothing set up") { SettingsSheet {}.themed() }
#Preview("Bundled token, dark") {
    SettingsSheet {}
        .environment(\.dependencies, .inMemory(credentials: InMemoryCredentials(bundledToken: "fake")))
        .themed().preferredColorScheme(.dark)
}
