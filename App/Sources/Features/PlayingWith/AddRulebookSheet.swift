import SwiftUI
import AckshuallyCore

/// ＋ Add a Rulebook, after picking the PDF (S1): a New Game, or Add to a game, as a core book or an add-on.
/// The grouping is always the user's choice; the app doesn't guess from titles.
struct AddRulebookSheet: View {
    struct Game: Identifiable, Equatable {
        var id: String
        var title: String
        /// "3 rulebooks" (nil for one).
        var detail: String?
    }

    var bookTitle: String
    var games: [Game]
    var onNewGame: () -> Void
    var onAdd: (String, BookRole) -> Void
    var onCancel: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("New Game", systemImage: "plus.rectangle.on.rectangle", action: onNewGame)
                        .accessibilityIdentifier("newGame")
                } footer: {
                    Text("“\(bookTitle)” becomes a game of its own.")
                }
                .listRowBackground(theme.colors.card)
                Section {
                    ForEach(games) { game in
                        AddToGameRow(game: game) { onAdd(game.id, $0) }
                    }
                } header: {
                    Text("Add to a Game")
                } footer: {
                    Text("Core books are always in play. Add-ons (expansions, FAQs, errata) are ticked each game night.")
                }
                .listRowBackground(theme.colors.card)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.groupedBackground)
            .navigationTitle("Add “\(bookTitle)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
            }
        }
        .accessibilityIdentifier("addRulebookSheet")
    }
}

#Preview {
    AddRulebookSheet(bookTitle: "Solar Expansion", games: PlayingWithFixtures.addTargets, onNewGame: {}, onAdd: { _, _ in }, onCancel: {})
        .themed()
}
#Preview("AX5, dark") {
    AddRulebookSheet(bookTitle: "Solar Expansion", games: PlayingWithFixtures.addTargets, onNewGame: {}, onAdd: { _, _ in }, onCancel: {})
        .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
