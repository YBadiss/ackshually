import SwiftUI

extension EnvironmentValues {
    @Entry var theme: Theme = .warm
}

/// Picks the palette for the color scheme and scales tokens for the Dynamic Type size.
/// Apply once at the root (and in previews); everything below reads `@Environment(\.theme)`.
struct ThemeProvider: ViewModifier {
    var light: Theme = .warm
    var dark: Theme = .warmDark
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content.environment(\.theme, (scheme == .dark ? dark : light).scaled(for: typeSize))
    }
}

extension View {
    func themed() -> some View { modifier(ThemeProvider()) }
}

/// Background from a theme color (resolved from the environment, so it follows dark mode).
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
