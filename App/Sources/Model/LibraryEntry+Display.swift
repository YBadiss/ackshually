import AckshuallyCore
extension LibraryEntry {
    /// "Root · Riverfolk, Rootbotics": the game and its ticked add-ons.
    var playingTitle: String {
        let ticked = addOns.filter(\.ticked).map(\.title)
        return ticked.isEmpty ? title : "\(title) · \(ticked.joined(separator: ", "))"
    }

    /// "7 rulebooks" under the name in My Games (nil for one book).
    var bookCountText: String? { books.count > 1 ? "\(books.count) rulebooks" : nil }
}
