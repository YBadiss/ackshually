import UIKit
import PDFKit
import AckshuallyCore

/// My Games fixtures: made-up game names (only the sample has a real file and cover).
@MainActor
enum LibraryFixtures {
    static let games: [LibraryEntry] = LibraryIndex(entries: [
        entry("power-plant-rush.pdf", "Power plant rush", ago: 120),
        entry("tile-garden.pdf", "Tile Garden", ago: 86_400 * 2),
        entry("woodland-court.pdf", "Woodland Court: Learning to Play", ago: 86_400 * 9),
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

    private static func entry(_ file: String, _ title: String, ago: TimeInterval) -> LibraryEntry {
        let d = Date.now.addingTimeInterval(-ago)
        return LibraryEntry(fileName: file, title: title, added: d, lastOpened: d)
    }
}
