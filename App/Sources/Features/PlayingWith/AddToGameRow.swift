import SwiftUI
import AckshuallyCore

/// A game in ＋ Add a Rulebook's "Add to a Game" list: tap → add the picked book as an add-on or a core book.
/// The choice is a dialog attached to this row, so it rises from the row tapped.
struct AddToGameRow: View {
    var game: AddRulebookSheet.Game
    var onAdd: (BookRole) -> Void
    @Environment(\.theme) private var theme
    @State private var choosing = false

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(game.title).font(theme.font.row).foregroundStyle(theme.colors.label)
                if let d = game.detail {
                    Text(d).font(theme.font.rowValue).foregroundStyle(theme.colors.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityIdentifier("addTo-\(game.id)")
        .confirmationDialog("Add to \(game.title)", isPresented: $choosing, titleVisibility: .visible) {
            Button("As an Add-on") { onAdd(.addOn) }
            Button("As a Core Book") { onAdd(.core) }
        } message: {
            Text("An add-on is an expansion, FAQ or errata you tick when it's on the table.")
        }
    }

    private func choose() { choosing = true }
}

#Preview {
    List { ForEach(PlayingWithFixtures.addTargets) { AddToGameRow(game: $0) { _ in } } }.themed()
}
#Preview("AX5, dark") {
    List { ForEach(PlayingWithFixtures.addTargets) { AddToGameRow(game: $0) { _ in } } }
        .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
