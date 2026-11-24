import Foundation
import AckshuallyCore

/// What the "Playing with" list (S13) shows for one game: its core books (always on) and its add-ons (ticked
/// for tonight). Built from the library index; the leaf views render it.
struct PlayingWithContent: Equatable {
    /// From My Games the list confirms with Play (then the game opens); from the viewer's title, with Done.
    enum Purpose: Equatable { case play, change }

    struct Book: Identifiable, Equatable {
        var fileName: String
        var title: String
        var role: BookRole
        var inPlay: Bool
        /// The game's last core book can't be removed or made an add-on.
        var isLastCore: Bool
        var id: String { fileName }
    }

    var gameTitle: String
    var core: [Book]
    var addOns: [Book]
    var purpose: Purpose
    /// Play was tapped and the books are being joined.
    var isOpening = false

    init(gameTitle: String, core: [Book], addOns: [Book], purpose: Purpose, isOpening: Bool = false) {
        self.gameTitle = gameTitle
        self.core = core
        self.addOns = addOns
        self.purpose = purpose
        self.isOpening = isOpening
    }

    init(_ game: LibraryEntry, purpose: Purpose, isOpening: Bool = false) {
        let books = game.books.map {
            Book(fileName: $0.fileName, title: $0.title, role: $0.role, inPlay: $0.inPlay, isLastCore: game.isLastCore($0.fileName))
        }
        self.init(gameTitle: game.title, core: books.filter { $0.role == .core }, addOns: books.filter { $0.role == .addOn },
                  purpose: purpose, isOpening: isOpening)
    }
}
