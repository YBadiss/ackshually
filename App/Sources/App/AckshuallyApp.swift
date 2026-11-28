import SwiftUI

@main
struct AckshuallyApp: App {
    /// The live services, created once: Keychain credentials, UserDefaults settings, the library folder,
    /// Claude / demo providers. Models get them by initialiser, Settings through the environment.
    private let dependencies: AppDependencies
    @State private var library: LibraryModel
    @State private var voice = AskController()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let d = AppDependencies.live()
        dependencies = d
        _library = State(initialValue: LibraryModel(dependencies: d, loadIndex: false))
    }

    var body: some Scene {
        WindowGroup {
            LibraryScreen(library: library, voice: voice)
                .environment(\.dependencies, dependencies)
                .themed()
                .task {
                    await library.load()
                    LaunchOptions.apply(to: library)
                }
        }
        // Deleted games and removed books can be undone until the app goes to the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await library.purgeRemovals() } }
        }
    }
}
