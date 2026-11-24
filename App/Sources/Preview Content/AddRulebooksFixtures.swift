import UIKit
import AckshuallyCore

/// "Add N Rulebooks" (S14) fixtures: made-up games around the sample (Power Plant Rush already in My Games,
/// Woodland Court new, a score pad skipped).
@MainActor
enum AddRulebooksFixtures {
    static let games: [LibraryEntry] = [
        LibraryEntry(fileName: Library.sampleFileName, title: "Power Plant Rush", added: .now, lastOpened: .now),
        LibraryEntry(fileName: "tile-garden.pdf", title: "Tile Garden", added: .now, lastOpened: .now),
    ]

    static let files: [(fileName: String, title: String)] = [
        (Library.sampleExpansionFileName, "solar-expansion"),
        ("woodland-law.pdf", "woodland-law"),
        ("woodland-learning.pdf", "woodland-learning"),
        ("woodland-rivers.pdf", "woodland-rivers"),
        ("score-pad.pdf", "score-pad"),
    ]

    static let suggestions: [RulebookSorter.Suggestion] = [
        .init(fileName: Library.sampleExpansionFileName, target: .existing(id: Library.sampleFileName), role: .addOn,
              title: "Solar Expansion", reason: "expansion for Power Plant Rush", notARulebook: false),
        .init(fileName: "woodland-law.pdf", target: .new(name: "Woodland Court"), role: .core,
              title: "Law of Woodland Court", reason: "rules reference", notARulebook: false),
        .init(fileName: "woodland-learning.pdf", target: .new(name: "Woodland Court"), role: .core,
              title: "Learning to Play", reason: "learning guide", notARulebook: false),
        .init(fileName: "woodland-rivers.pdf", target: .new(name: "Woodland Court"), role: .addOn,
              title: "Rivers", reason: "expansion", notARulebook: false),
        .init(fileName: "score-pad.pdf", target: .new(name: "Woodland Court"), role: .addOn,
              title: "Score Pad", reason: "score sheet, not a rulebook", notARulebook: true),
    ]

    static var sortingBatch: ImportBatch { ImportBatch(files: files) }

    static var suggestedBatch: ImportBatch {
        var b = sortingBatch
        b.apply(suggestions, games: games)
        return b
    }

    static var unsortedBatch: ImportBatch {
        var b = sortingBatch
        b.leaveUnsorted(games: games)
        return b
    }

    static var sorting: AddRulebooksContent { AddRulebooksContent(batch: sortingBatch, games: games) }
    static var suggested: AddRulebooksContent { AddRulebooksContent(batch: suggestedBatch, games: games) }
    static var unsorted: AddRulebooksContent { AddRulebooksContent(batch: unsortedBatch, games: games) }

    static var covers: [String: UIImage] { LibraryFixtures.cover.map { [Library.sampleExpansionFileName: $0] } ?? [:] }

    static func book(_ file: String, _ title: String, reason: String? = nil) -> ImportBatch.Book {
        ImportBatch.Book(fileName: file, title: title, reason: reason)
    }

    static func sheet(_ c: AddRulebooksContent) -> AddRulebooksSheet {
        AddRulebooksSheet(content: c, covers: covers, loadCover: { _, _, _ in }, actions: .none)
    }
}
