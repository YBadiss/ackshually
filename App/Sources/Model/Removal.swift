import UIKit
import AckshuallyCore

/// A deleted game (or several) or a removed book that can still be undone: shake, three-finger swipe, or Undo
/// on My Games' bar. Its PDFs wait in the pending-deletion folder until the app goes to the background.
struct Removal: Identifiable, Equatable {
    enum Kind: Equatable {
        case games([LibraryEntry])
        /// The book, the game it was in, and its place among that game's books.
        case book(LibraryBook, gameID: String, position: Int)
    }

    let id = UUID()
    var kind: Kind
    /// Covers to put back, so the rows don't re-render them.
    var covers: [String: UIImage] = [:]

    var fileNames: [String] {
        switch kind {
        case .games(let games): games.flatMap(\.books).map(\.fileName)
        case .book(let book, _, _): [book.fileName]
        }
    }

    /// The bar's text: "Deleted Root", "Deleted 2 Games", "Removed Riverfolk".
    var message: String {
        switch kind {
        case .games(let games): games.count == 1 ? "Deleted \(games[0].title)" : "Deleted \(games.count) Games"
        case .book(let book, _, _): "Removed \(book.title)"
        }
    }

    /// The undo menu's "Undo Delete Game".
    var actionName: String {
        switch kind {
        case .games(let games): games.count == 1 ? "Delete Game" : "Delete Games"
        case .book: "Remove Rulebook"
        }
    }
}
