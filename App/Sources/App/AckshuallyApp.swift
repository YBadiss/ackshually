import SwiftUI

@main
struct AckshuallyApp: App {
    @State private var model = ViewerModel()
    @State private var voice = AskController()

    var body: some Scene {
        WindowGroup {
            ViewerScreen(model: model, voice: voice)
                .themed()
                .task { LaunchOptions.apply(to: model) }
        }
    }
}
