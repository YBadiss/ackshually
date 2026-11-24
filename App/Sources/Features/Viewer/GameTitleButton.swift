import SwiftUI

/// The viewer's title as a button (S13): "Root · Riverfolk, Rootbotics", the game and the add-ons ticked
/// tonight. Tap → "Playing with", to change the books from the next question.
struct GameTitleButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                Text(title)
                    .font(theme.font.titleButton)
                    .foregroundStyle(theme.colors.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(theme.font.titleChevron)
                    .foregroundStyle(theme.colors.secondaryLabel)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Shows the rulebooks you're playing with")
        .accessibilityIdentifier("gameTitleButton")
    }
}

#Preview {
    NavigationStack {
        Fixtures.pageBackdrop.navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { GameTitleButton(title: "Power Plant Rush · Solar Expansion") {} } }
            .viewerChrome()
    }
    .themed()
}
#Preview("Long, AX5, dark") {
    NavigationStack {
        Fixtures.pageBackdrop.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { GameTitleButton(title: "Woodland Court · Rivers, Marsh, FAQ and Errata") {} }
            }
            .viewerChrome()
    }
    .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
