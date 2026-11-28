import SwiftUI

/// One game in My Games: cover, name, how many rulebooks it has (when more than one), and when it was last
/// opened. VoiceOver reads it as one element: the list combines it.
struct GameRow: View {
    var title: String
    /// "7 rulebooks"; nil for a game with one.
    var books: String? = nil
    var lastOpened: Date
    var cover: UIImage?
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Cover beside the text; at accessibility sizes the cover goes above it, so the text gets the row's
    /// whole width instead of breaking words (#27).
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.m))
            : AnyLayout(HStackLayout(spacing: theme.spacing.l))
    }

    var body: some View {
        layout {
            GameCover(image: cover)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.font.gameTitle)
                    .foregroundStyle(theme.colors.label)
                    .accessibilityIdentifier("gameTitle")
                if let books {
                    Text(books)
                        .font(theme.font.gameDetail)
                        .foregroundStyle(theme.colors.secondaryLabel)
                        .accessibilityIdentifier("gameBooks")
                }
                Text("Opened \(lastOpened, format: .relative(presentation: .named))")
                    .font(theme.font.gameDetail)
                    .foregroundStyle(theme.colors.secondaryLabel)
                    .accessibilityIdentifier("gameOpened")
            }
        }
        .padding(.vertical, theme.spacing.xs)
    }
}

#Preview("States") {
    List {
        GameRow(title: "Power Plant Rush", lastOpened: .now.addingTimeInterval(-90), cover: LibraryFixtures.cover)
        GameRow(title: "Azul", lastOpened: .now.addingTimeInterval(-86_400 * 2), cover: nil)
        GameRow(title: "Woodland Court", books: "7 rulebooks", lastOpened: .now.addingTimeInterval(-86_400 * 9), cover: nil)
        GameRow(title: "Root: The Law of Root, Learning to Play edition", lastOpened: .now.addingTimeInterval(-86_400 * 40), cover: nil)
    }
    .themed()
}
#Preview("AX5, selecting") {
    LibraryFixtures.selecting(selected: ["tile-garden.pdf"]).themed().dynamicTypeSize(.accessibility5)
}
#Preview("AX5") {
    List { GameRow(title: "Power Plant Rush", books: "2 rulebooks", lastOpened: .now.addingTimeInterval(-3600), cover: LibraryFixtures.cover) }
        .themed()
        .dynamicTypeSize(.accessibility5)
}
