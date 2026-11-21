import SwiftUI

/// Previews the whole viewer from fixtures (no API key).
struct ViewerPreview: View {
    var state: Fixtures.ModelState = .answered
    var detent: SheetDetent = .medium
    @State private var model: ViewerModel?
    @State private var voice = AskController()
    @State private var presentation = ViewerPresentation()
    @State private var windowSize = CGSize.zero

    var body: some View {
        NavigationStack {
            if let model, let rb = model.rulebook {
                AdaptiveViewerLayout(model: model, voice: voice, document: rb.pdf, presentation: presentation, windowSize: windowSize)
                    .navigationTitle(rb.title).navigationBarTitleDisplayMode(.inline)
                    .viewerChrome()
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
        .onAppear { model = Fixtures.model(state, detent: detent) }
    }
}
