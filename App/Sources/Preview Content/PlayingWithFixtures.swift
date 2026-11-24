import Foundation
import AckshuallyCore

/// "Playing with" (S13) and ＋ Add a Rulebook fixtures: Power Plant Rush with its made-up add-ons.
@MainActor
enum PlayingWithFixtures {
    static let sampleID = Library.sampleFileName

    static let content = PlayingWithContent(gameTitle: "Power Plant Rush", core: [
        .init(fileName: sampleID, title: "Power Plant Rush", role: .core, inPlay: true, isLastCore: true),
    ], addOns: [
        .init(fileName: Library.sampleExpansionFileName, title: "Solar Expansion", role: .addOn, inPlay: true, isLastCore: false),
        .init(fileName: "storms.pdf", title: "Storms", role: .addOn, inPlay: false, isLastCore: false),
        .init(fileName: "faq.pdf", title: "FAQ and Errata (2024)", role: .addOn, inPlay: true, isLastCore: false),
    ], purpose: .play)

    static let oneBook = PlayingWithContent(gameTitle: "Tile Garden", core: [
        .init(fileName: "tile-garden.pdf", title: "Tile Garden", role: .core, inPlay: true, isLastCore: true),
    ], addOns: [], purpose: .change)

    static var opening: PlayingWithContent { var c = content; c.isOpening = true; return c }

    static let addTargets: [AddRulebookSheet.Game] = [
        .init(id: sampleID, title: "Power Plant Rush", detail: "2 rulebooks"),
        .init(id: "tile-garden.pdf", title: "Tile Garden", detail: nil),
        .init(id: "woodland-court.pdf", title: "Woodland Court", detail: "7 rulebooks"),
    ]

    static func sheet(_ c: PlayingWithContent) -> PlayingWithSheet {
        PlayingWithSheet(content: c, onToggle: { _ in }, onRemove: { _ in }, onSetRole: { _, _ in }, onRename: { _, _ in },
                         onRenameGame: { _ in }, onAdd: {}, onConfirm: {}, onClose: {})
    }

    /// A library holding the sample with Solar Expansion (ticked) as an add-on, both real generated files.
    static func library() -> LibraryModel {
        let storage = InMemoryLibraryStorage()
        let model = LibraryModel(dependencies: .inMemory(library: storage))
        model.seedSampleSet()
        return model
    }
}
