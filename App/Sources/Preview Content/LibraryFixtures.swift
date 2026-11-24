import SwiftUI
import PDFKit
import AckshuallyCore

/// My Games fixtures: made-up game names (only the sample has a real file and cover).
@MainActor
enum LibraryFixtures {
    static let games: [LibraryEntry] = LibraryIndex(entries: [
        entry("power-plant-rush.pdf", "Power plant rush", ago: 120),
        entry("tile-garden.pdf", "Tile Garden", ago: 86_400 * 2),
        woodlandCourt(ago: 86_400 * 9),
        entry("spice-desert.pdf", "Spice Desert", ago: 86_400 * 45),
    ]).entries

    /// The sample's first page, rendered like the real cover.
    static let cover: UIImage? = {
        guard let page = PDFDocument(url: Fixtures.rulebookURL)?.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 88, height: 118), for: .cropBox)
    }()

    static var covers: [String: UIImage] { cover.map { ["power-plant-rush.pdf": $0] } ?? [:] }

    static func model(games: [LibraryEntry] = games) -> LibraryModel {
        let m = LibraryModel(dependencies: .inMemory(library: InMemoryLibraryStorage(index: LibraryIndex(entries: games))))
        if let cover { m.setCover(cover, for: "power-plant-rush.pdf") }
        return m
    }

    /// My Games in Edit mode with `selected` ticked: the list and its toolbar (Delete (N) at the bottom).
    static func editing(selected: Set<String>) -> some View {
        NavigationStack {
            GameList(games: games, covers: covers, selection: .constant(selected), loadCover: { _, _, _ in }, onDelete: { _ in })
                .environment(\.editMode, .constant(.active))
                .navigationTitle("My Games")
                .toolbar {
                    LibraryToolbar(isEditing: true, selectedCount: selected.count, canEdit: true, onAdd: {}, onSettings: {},
                                   onToggleEditing: {}, onDeleteSelected: {})
                }
                .themeBackground(\.groupedBackground)
        }
    }

    /// A game with seven rulebooks (S13): two core books and five add-ons, two of them ticked.
    private static func woodlandCourt(ago: TimeInterval) -> LibraryEntry {
        let d = Date.now.addingTimeInterval(-ago)
        let books = [
            LibraryBook(fileName: "woodland-court.pdf", title: "Law of Woodland Court", role: .core),
            LibraryBook(fileName: "woodland-court-learning.pdf", title: "Learning to Play", role: .core),
            LibraryBook(fileName: "woodland-rivers.pdf", title: "Rivers", role: .addOn, ticked: true),
            LibraryBook(fileName: "woodland-tunnels.pdf", title: "Tunnels", role: .addOn, ticked: false),
            LibraryBook(fileName: "woodland-raiders.pdf", title: "Raiders", role: .addOn, ticked: false),
            LibraryBook(fileName: "woodland-marsh.pdf", title: "Marsh", role: .addOn, ticked: true),
            LibraryBook(fileName: "woodland-gears.pdf", title: "Gears", role: .addOn, ticked: false),
        ]
        return LibraryEntry(id: "woodland-court.pdf", title: "Woodland Court", added: d, lastOpened: d, books: books)
    }

    private static func entry(_ file: String, _ title: String, ago: TimeInterval) -> LibraryEntry {
        let d = Date.now.addingTimeInterval(-ago)
        return LibraryEntry(fileName: file, title: title, added: d, lastOpened: d)
    }
}
