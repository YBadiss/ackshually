import SwiftUI

/// Shows the library's undo bar ("Deleted Root · Undo", "Removed Riverfolk · Undo") at the bottom of a screen
/// (My Games, Playing with), and lets it go after `theme.layout.undoBarDuration`; the undo itself stays (shake)
/// until the app goes to the background.
struct UndoBarInset: ViewModifier {
    var library: LibraryModel
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let removal = library.undoBar {
                UndoBar(message: removal.message) { withAnimation(.snappy) { library.undo(removal) } }
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.bottom, theme.spacing.m)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: removal.id) {
                        try? await Task.sleep(for: theme.layout.undoBarDuration)
                        withAnimation(.snappy) { library.dismissUndoBar(removal) }
                    }
            }
        }
    }
}

extension View {
    func undoBar(_ library: LibraryModel) -> some View { modifier(UndoBarInset(library: library)) }
}
