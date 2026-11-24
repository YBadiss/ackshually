import Foundation

/// What My Games pushes: a game from the library (by its id), or a file opened by a launch argument
/// (`-pdfPath`, `-sample`) that is not part of the library.
enum GameRoute: Hashable {
    case game(id: String)
    case file(URL)
}
