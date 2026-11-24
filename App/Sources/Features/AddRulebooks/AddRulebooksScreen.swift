import SwiftUI
import AckshuallyCore

/// "Add N Rulebooks" bound to the library (`LibraryModel`, from the environment): shown from My Games and from a
/// game's "Playing with" while a review is open. It can't be swiped away: Cancel removes the copies.
struct AddRulebooksScreen: View {
    @Environment(LibraryModel.self) private var library: LibraryModel?

    var body: some View {
        if let library, let batch = library.review {
            AddRulebooksSheet(
                content: AddRulebooksContent(batch: batch, games: library.games),
                covers: library.covers,
                loadCover: { await library.loadCover(fileName: $0, pixelWidth: $1, scale: $2) },
                actions: AddRulebooksActions(
                    move: { files, group, before in for f in files { library.moveBook(f, toGroup: group, before: before) } },
                    moveTo: { file, kind in
                        switch kind {
                        case .group(let id): library.moveBook(file, toGroup: id)
                        case .game(let id): library.moveBook(file, toGame: id)
                        }
                    },
                    moveToNewGame: { library.moveBookToNewGame($0) },
                    skip: { $0.forEach(library.skipBook) },
                    setRole: { library.setReviewRole($0, $1) },
                    renameBook: { library.renameReviewBook($0, to: $1) },
                    renameGroup: { library.renameReviewGroup($0, to: $1) },
                    add: { library.confirmReview() },
                    cancel: { library.cancelReview() }))
                .interactiveDismissDisabled()
        } else {
            Color.clear
        }
    }
}

extension View {
    /// Presents "Add N Rulebooks" while `library` reviews a batch started here (`gameID` nil: My Games).
    func addRulebooksSheet(_ library: LibraryModel, from gameID: String? = nil) -> some View {
        sheet(isPresented: Binding(get: { library.review != nil && library.review?.preferredGameID == gameID },
                                   set: { if !$0 { library.cancelReview() } }),
              onDismiss: { library.reviewDismissed() }) {
            AddRulebooksScreen().themed()
        }
    }
}
