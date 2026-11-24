import SwiftUI

/// A game's header in "Add N Rulebooks" (S14): its name (a new game's can be renamed) and whether it is new or
/// already in My Games.
struct ReviewGroupHeader: View {
    var name: String
    /// "New game" / "In My Games".
    var badge: String
    /// nil: not renamable (a game already in My Games).
    var onRename: (() -> Void)?
    @Environment(\.theme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { title; Spacer(minLength: theme.spacing.m); badgeText }
            VStack(alignment: .leading, spacing: theme.spacing.xxs) { title; badgeText }
        }
    }

    @ViewBuilder private var title: some View {
        if let onRename {
            Button(action: onRename) {
                Label(name, systemImage: "pencil").labelStyle(TrailingIconLabelStyle())
            }
            .accessibilityHint("Renames this new game")
        } else {
            Text(name)
        }
    }

    private var badgeText: some View {
        Text(badge)
            .textCase(nil)
            .foregroundStyle(theme.colors.secondaryLabel)
    }
}

#Preview {
    List {
        Section { Text("Law of Root") } header: { ReviewGroupHeader(name: "Root", badge: "In My Games", onRename: nil) }
        Section { Text("Azul") } header: { ReviewGroupHeader(name: "Azul", badge: "New game", onRename: {}) }
    }
    .themed()
}
#Preview("AX5") {
    List {
        Section { Text("Azul") } header: { ReviewGroupHeader(name: "Dune: Imperium Uprising", badge: "New game", onRename: {}) }
    }
    .themed().dynamicTypeSize(.accessibility5)
}
