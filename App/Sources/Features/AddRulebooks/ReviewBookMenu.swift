import SwiftUI

/// Long-press on a book in "Add N Rulebooks" (S14): Move to… another game of the sheet, a game in My Games or a
/// new one; Rename; Skip.
struct ReviewBookMenu: View {
    var targets: [AddRulebooksContent.MoveTarget]
    /// False for a book already skipped.
    var canSkip: Bool
    var onMove: (AddRulebooksContent.MoveTarget.Kind) -> Void
    var onNewGame: () -> Void
    var onRename: () -> Void
    var onSkip: () -> Void

    var body: some View {
        Menu("Move to…", systemImage: "arrow.right.square") {
            ForEach(targets) { target in
                Button(target.title) { onMove(target.kind) }
            }
            Divider()
            Button("New Game", systemImage: "plus", action: onNewGame)
        }
        Button("Rename", systemImage: "pencil", action: onRename)
        if canSkip {
            Button("Skip", systemImage: "nosign", role: .destructive, action: onSkip)
        }
    }
}

#Preview {
    Text("Long-press me")
        .contextMenu {
            ReviewBookMenu(targets: AddRulebooksFixtures.suggested.moveTargets(for: "woodland-rivers.pdf"), canSkip: true,
                           onMove: { _ in }, onNewGame: {}, onRename: {}, onSkip: {})
        }
        .themed()
}
