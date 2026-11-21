import SwiftUI

extension EnvironmentValues {
    @Entry var theme: Theme = .warm
}

/// Scales the tokens for the Dynamic Type size (colors are dynamic and follow dark mode on
/// their own). Apply once at the root (and in previews); everything below reads `@Environment(\.theme)`.
struct ThemeProvider: ViewModifier {
    var base: Theme = .warm
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content
            .environment(\.theme, base.scaled(for: typeSize))
            .tint(base.colors.tint)
    }
}

extension View {
    func themed() -> some View { modifier(ThemeProvider()) }
}

/// Background from a theme color (resolved from the environment).
struct ThemeBackground: ViewModifier {
    var color: KeyPath<Theme.Colors, Color>
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.background(theme.colors[keyPath: color])
    }
}

extension View {
    func themeBackground(_ color: KeyPath<Theme.Colors, Color>) -> some View { modifier(ThemeBackground(color: color)) }
}
