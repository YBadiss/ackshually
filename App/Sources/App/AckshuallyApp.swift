import SwiftUI

@main
struct AckshuallyApp: App {
    @State private var library = LibraryModel(viewer: ViewerModel())
    @State private var voice = AskController()

    var body: some Scene {
        WindowGroup {
            LibraryScreen(library: library, voice: voice)
                .themed()
                .task { LaunchOptions.apply(to: library) }
        }
    }
}
