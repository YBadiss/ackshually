import SwiftUI

/// One game in My Games: cover, name, and when it was last opened.
struct GameRow: View {
    var title: String
    var lastOpened: Date
    var cover: UIImage?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            GameCover(image: cover)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.font.gameTitle)
                    .foregroundStyle(theme.colors.label)
                Text("Opened \(lastOpened, format: .relative(presentation: .named))")
                    .font(theme.font.gameDetail)
                    .foregroundStyle(theme.colors.secondaryLabel)
            }
        }
        .padding(.vertical, theme.spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview("States") {
    List {
        GameRow(title: "Power Plant Rush", lastOpened: .now.addingTimeInterval(-90), cover: LibraryFixtures.cover)
        GameRow(title: "Azul", lastOpened: .now.addingTimeInterval(-86_400 * 2), cover: nil)
        GameRow(title: "Root: The Law of Root, Learning to Play edition", lastOpened: .now.addingTimeInterval(-86_400 * 40), cover: nil)
    }
    .themed()
}
#Preview("AX5") {
    List { GameRow(title: "Power Plant Rush", lastOpened: .now.addingTimeInterval(-3600), cover: LibraryFixtures.cover) }
        .themed()
        .dynamicTypeSize(.accessibility5)
}
