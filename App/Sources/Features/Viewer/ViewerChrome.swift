import SwiftUI

/// Warm-tinted navigation bar over the PDF canvas.
struct ViewerChrome: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.colors.bar, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

extension View {
    func viewerChrome() -> some View { modifier(ViewerChrome()) }
}
