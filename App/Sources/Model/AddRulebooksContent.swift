import Foundation
import AckshuallyCore

/// What the "Add N Rulebooks" sheet (S14) shows: the review batch and where each book can move. Built from
/// `ImportBatch` and My Games; the leaf views render it.
struct AddRulebooksContent: Equatable {
    /// One entry of a row's Move to… menu.
    struct MoveTarget: Identifiable, Equatable {
        enum Kind: Equatable {
            /// A group already in the sheet.
            case group(String)
            /// A game in My Games with no group in the sheet yet.
            case game(String)
        }
        var kind: Kind
        var title: String
        var id: String {
            switch kind {
            case .group(let id): "group:\(id)"
            case .game(let id): "game:\(id)"
            }
        }
    }

    var batch: ImportBatch
    /// Games in My Games, for Move to…
    var games: [(id: String, title: String)]

    init(batch: ImportBatch, games: [LibraryEntry]) {
        self.batch = batch
        self.games = games.map { ($0.id, $0.title) }
    }

    static func == (a: Self, b: Self) -> Bool {
        a.batch == b.batch && a.games.map(\.id) == b.games.map(\.id) && a.games.map(\.title) == b.games.map(\.title)
    }

    /// "Add 13 Rulebooks", "Add a Rulebook".
    var title: String {
        let n = batch.fileNames.count
        return n == 1 ? "Add a Rulebook" : "Add \(n) Rulebooks"
    }

    var canAdd: Bool { !batch.isSorting && batch.bookCount > 0 }

    /// The note under the groups.
    var note: String? {
        switch batch.origin {
        case .sorting: nil
        case .suggested: "Suggested from the titles and first pages. Check the groups before adding."
        case .unsorted: "Sort these yourself: drag a rulebook onto another game, or long-press it → Move to."
        }
    }

    /// "New game" / "In My Games".
    static func badge(_ group: ImportBatch.Group) -> String { group.isNew ? "New game" : "In My Games" }

    /// Every other group of the sheet, then games of My Games not in it yet.
    func moveTargets(for fileName: String) -> [MoveTarget] {
        let current = batch.group(containing: fileName)?.id
        let inSheet = batch.groups.filter { $0.id != current }.map { MoveTarget(kind: .group($0.id), title: $0.name) }
        let taken = Set(batch.groups.compactMap { if case .existing(let id) = $0.target { id } else { nil } })
        let others = games.filter { !taken.contains($0.id) }.map { MoveTarget(kind: .game($0.id), title: $0.title) }
        return inSheet + others
    }
}
