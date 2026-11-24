import SwiftUI
import UIKit
import Observation

struct ViewerDialogs: ViewModifier {
    @Bindable var presentation: ViewerPresentation
    var model: ViewerModel
    var active: Bool
    @Environment(LibraryModel.self) private var library: LibraryModel?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: active ? $presentation.settings : .constant(false)) {
                SettingsSheet { presentation.settings = false }
                    .themed()
            }
            .sheet(isPresented: active ? $presentation.answerDetails : .constant(false)) {
                AnswerDetailsView(reports: model.answerDetails?.evidence ?? [], route: model.routeLabel,
                                  onCopy: { UIPasteboard.general.string = model.answerDetails?.json },
                                  onDone: { presentation.answerDetails = false })
                    .themed()
            }
            // However it closes (Done or a swipe), the open game picks up the books now ticked.
            .sheet(isPresented: active ? $presentation.playingWith : .constant(false),
                   onDismiss: { if case .game(let id)? = model.route { library?.booksChanged(id) } }) {
                if case .game(let id)? = model.route {
                    PlayingWithScreen(gameID: id, purpose: .change) { presentation.playingWith = false }
                        .presentationDetents([.medium, .large])
                        .themed()
                }
            }
    }
}

extension View {
    func viewerDialogs(model: ViewerModel, active: Bool) -> some View {
        modifier(ViewerDialogs(presentation: model.presentation, model: model, active: active))
    }
}
