import SwiftUI

/// Glass for the floating field (rounder while holding, when the transcript panel shows);
/// a plain fill on the sheet, where glass on glass would muddy the text.
struct AskFieldBackground: ViewModifier {
    var style: AskField.Style
    var expanded: Bool
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        switch style {
        case .floating:
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: expanded ? theme.radius.group : 100))
        case .inline:
            content.background(theme.colors.fieldFill, in: .rect(cornerRadius: theme.radius.field))
        }
    }
}
