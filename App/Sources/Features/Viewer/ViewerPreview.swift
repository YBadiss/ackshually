import SwiftUI

/// Previews the whole viewer from fixtures (no API key).
struct ViewerPreview: View {
    var state: Fixtures.ModelState = .answered
    var detent: SheetDetent = .medium
    @State private var model: ViewerModel?
    @State private var voice = AskController()
    @State private var windowSize = CGSize.zero

    var body: some View {
        NavigationStack {
            if let model {
                AdaptiveViewerLayout(model: model, voice: voice, document: model.rulebook.pdf, windowSize: windowSize)
                    .navigationTitle(model.rulebook.title).navigationBarTitleDisplayMode(.inline)
                    .viewerChrome()
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
        .onAppear { model = Fixtures.model(state, detent: detent) }
    }
}
