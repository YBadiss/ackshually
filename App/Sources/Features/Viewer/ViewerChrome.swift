import SwiftUI

/// Navigation bar in a darker warm tone than the canvas and the answer sheet / column.
struct ViewerChrome: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.colors.navigationBar, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

extension View {
    func viewerChrome() -> some View { modifier(ViewerChrome()) }
}
