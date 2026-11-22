import SwiftUI
import UIKit
import Observation

struct ViewerDialogs: ViewModifier {
    @Bindable var presentation: ViewerPresentation
    var model: ViewerModel
    var active: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: active ? $presentation.settings : .constant(false)) {
                SettingsSheet { presentation.settings = false }
                    .themed()
            }
            .sheet(isPresented: active ? $presentation.answerDetails : .constant(false)) {
                AnswerDetailsView(reports: model.evidenceReports, route: model.routeLabel,
                                  onCopy: { UIPasteboard.general.string = model.answerDetails?.json },
                                  onDone: { presentation.answerDetails = false })
                    .themed()
            }
    }
}

extension View {
    func viewerDialogs(_ p: ViewerPresentation, model: ViewerModel, active: Bool) -> some View {
        modifier(ViewerDialogs(presentation: p, model: model, active: active))
    }
}
