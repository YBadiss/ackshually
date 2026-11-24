import XCTest
import PDFKit
import AckshuallyCore
@testable import Ackshually

/// Adding several rulebooks (S14) and removing games in `LibraryModel`: the review opens at once, groups arrive
/// from the suggestion (or not, without a server route), nothing is saved until Add, Cancel removes the copies;
/// deleting several games, the confirmation for games with several books, Remove All Games, the only book.
@MainActor
final class AddRulebooksModelTests: XCTestCase {
    private var storage: InMemoryLibraryStorage!
    private let id = Library.sampleFileName
    private let solar = Library.sampleExpansionFileName

    private func library(_ suggestions: ScriptedSuggestions = ScriptedSuggestions(reply: nil)) -> LibraryModel {
        storage = InMemoryLibraryStorage(folder: FileManager.default.temporaryDirectory
            .appending(path: "add-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
        let l = LibraryModel(dependencies: .inMemory(library: storage, suggestions: suggestions))
        l.seedSampleSet()
        return l
    }

    private func picked(_ names: String...) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appending(path: "picked-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try names.map { try FixtureRulebook.write(to: dir.appending(path: $0), pages: FixtureRulebook.expansionPages) }
    }

    private func eventually(_ what: String, timeout: Duration = .seconds(5), file: StaticString = #filePath, line: UInt = #line,
                            _ condition: () -> Bool) async {
        let clock = ContinuousClock(), end = clock.now + timeout
        while clock.now < end {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("timed out waiting for \(what)", file: file, line: line)
    }

    private func exists(_ fileName: String) -> Bool { FileManager.default.fileExists(atPath: storage.url(for: fileName).path) }

    // MARK: Adding

    func testWithoutSuggestionsEachFileIsItsOwnGameAndOneNewGameOpens() async throws {
        let l = library()
        l.addRulebooks(try picked("tile-garden.pdf"))
        XCTAssertNotNil(l.review, "the sheet opens at once")
        await eventually("unsorted") { l.review?.isSorting == false }
        XCTAssertEqual(l.review?.origin, .unsorted)
        XCTAssertEqual(l.review?.groups.map(\.name), ["Tile garden"])
        XCTAssertEqual(l.games.count, 1, "nothing is saved before Add")
        l.confirmReview()
        XCTAssertNil(l.review)
        XCTAssertEqual(l.games.count, 2)
        XCTAssertTrue(l.path.isEmpty, "not while the sheet is still up")
        l.reviewDismissed()
        XCTAssertEqual(l.path, [.game(id: "tile-garden.pdf")])
    }

    func testSuggestionsGroupTheFilesAndAddSkipsTheFlaggedOnes() async throws {
        let l = library(ScriptedSuggestions(reply: .success([
            .init(fileName: "garden-rules.pdf", target: .new(name: "Tile Garden"), role: .core, title: "Rulebook",
                  reason: "base rules", notARulebook: false),
            .init(fileName: "garden-faq.pdf", target: .new(name: "Tile Garden"), role: .addOn, title: "FAQ",
                  reason: "faq", notARulebook: false),
            .init(fileName: "storms.pdf", target: .existing(id: id), role: .addOn, title: "Storms",
                  reason: "expansion", notARulebook: false),
            .init(fileName: "score.pdf", target: .new(name: "Tile Garden"), role: .addOn, title: "Score Pad",
                  reason: "score sheet", notARulebook: true),
        ]), delay: .milliseconds(50)))
        l.addRulebooks(try picked("garden-rules.pdf", "garden-faq.pdf", "storms.pdf", "score.pdf", "notes.txt"))
        XCTAssertEqual(l.review?.sorting.count, 4, "every PDF starts under Sorting… (not the .txt)")
        await eventually("suggested") { l.review?.origin == .suggested }
        let batch = try XCTUnwrap(l.review)
        XCTAssertEqual(batch.groups.map(\.name), ["Tile Garden", "Power plant rush"])
        XCTAssertEqual(batch.skipped.map(\.fileName), ["score.pdf"])
        XCTAssertEqual(AddRulebooksContent(batch: batch, games: l.games).title, "Add 4 Rulebooks")

        // Move the FAQ to Power Plant Rush by hand, then Add.
        l.moveBook("garden-faq.pdf", toGroup: "game:\(id)")
        l.confirmReview()
        XCTAssertEqual(l.game("garden-rules.pdf")?.books.map(\.title), ["Rulebook"])
        XCTAssertEqual(l.game(id)?.books.map(\.title), ["Power plant rush", "Solar Expansion", "Storms", "FAQ"])
        await eventually("the skipped copy is deleted") { !exists("score.pdf") }
        XCTAssertTrue(exists("garden-faq.pdf"))
        l.reviewDismissed()
        XCTAssertTrue(l.path.isEmpty, "a new game plus another game's books: back to My Games")
    }

    func testAFailedSuggestionLeavesTheFilesUnsorted() async throws {
        let l = library(ScriptedSuggestions(reply: .failure(.badReply("nope"))))
        l.addRulebooks(try picked("a.pdf", "b.pdf"))
        await eventually("unsorted") { l.review?.origin == .unsorted }
        XCTAssertEqual(l.review?.groups.count, 2)
        XCTAssertEqual(AddRulebooksContent(batch: try XCTUnwrap(l.review), games: l.games).note?.hasPrefix("Sort these yourself"), true)
    }

    func testFromPlayingWithTheFilesGoToThatGame() async throws {
        let l = library()
        l.addRulebooks(try picked("power-plant-rush-storms.pdf"), to: id)
        await eventually("unsorted") { l.review?.isSorting == false }
        let group = try XCTUnwrap(l.review?.groups.first)
        XCTAssertEqual(group.target, .existing(id))
        XCTAssertEqual(group.books.first?.title, "Storms", "the game's name is implied")
        XCTAssertEqual(group.books.first?.role, .addOn)
        l.confirmReview()
        l.reviewDismissed()
        XCTAssertEqual(l.game(id)?.bookCountText, "3 rulebooks")
        XCTAssertTrue(l.path.isEmpty, "back to the game's list, which is still up")
    }

    func testCancelRemovesEveryCopy() async throws {
        let l = library()
        l.addRulebooks(try picked("a.pdf", "b.pdf"))
        XCTAssertTrue(exists("a.pdf") && exists("b.pdf"))
        l.cancelReview()
        XCTAssertNil(l.review)
        await eventually("the copies are deleted") { !exists("a.pdf") && !exists("b.pdf") }
        XCTAssertEqual(l.games.count, 1)
    }

    func testACopyNeverReplacesAnotherBooksFile() throws {
        let l = library()
        l.addRulebooks(try picked(id))
        XCTAssertEqual(l.review?.fileNames, ["power-plant-rush 2.pdf"])
        XCTAssertEqual(PDFDocument(url: storage.url(for: id))?.pageCount, 4, "the sample's file is untouched")
    }

    func testANewGameWithAddOnsShowsItsListFirst() async throws {
        let l = library(ScriptedSuggestions(reply: .success([
            .init(fileName: "x.pdf", target: .new(name: "X"), role: .core, title: "X", reason: "", notARulebook: false),
            .init(fileName: "x-faq.pdf", target: .new(name: "X"), role: .addOn, title: "FAQ", reason: "", notARulebook: false),
        ])))
        l.addRulebooks(try picked("x.pdf", "x-faq.pdf"))
        await eventually("suggested") { l.review?.origin == .suggested }
        l.confirmReview()
        l.reviewDismissed()
        XCTAssertEqual(l.checklist?.id, "x.pdf")
    }

    // MARK: Removing

    func testDeletingAGameWithSeveralBooksAsksFirst() async throws {
        let l = library()
        let game = try XCTUnwrap(l.game(id))
        l.requestDelete([game])
        XCTAssertEqual(l.pendingDeletion?.question, "Delete Power plant rush and its 2 rulebooks?")
        XCTAssertNotNil(l.game(id), "not before the confirmation")
        l.confirmDeletion()
        XCTAssertNil(l.game(id))
        await eventually("files deleted") { !exists(id) && !exists(solar) }
    }

    func testEditDeleteSeveralAndRemoveAll() throws {
        let index = LibraryIndex(entries: AddRulebooksFixtures.games + [LibraryEntry(fileName: "c.pdf", title: "C", added: .now, lastOpened: .now)])
        storage = InMemoryLibraryStorage(index: index)
        let m = LibraryModel(dependencies: .inMemory(library: storage))
        let one = try XCTUnwrap(m.game("c.pdf"))
        m.requestDelete([one])
        XCTAssertNil(m.pendingDeletion, "one game with one book goes at once")
        XCTAssertNil(m.game("c.pdf"))
        m.requestDelete(m.games)
        XCTAssertEqual(m.pendingDeletion?.question, "Delete 2 games and their 2 rulebooks?")
        m.confirmDeletion()
        XCTAssertTrue(m.games.isEmpty)
        XCTAssertTrue(storage.loadIndex().isEmpty, "saved")

        let n = library()
        n.navigationPath = [.game(id: id)]
        n.removeAllGames()
        XCTAssertTrue(n.games.isEmpty)
        XCTAssertTrue(n.path.isEmpty)
    }

    func testRemovingTheOnlyBookDeletesTheGame() throws {
        storage = InMemoryLibraryStorage(index: LibraryIndex(entries: AddRulebooksFixtures.games))
        let m = LibraryModel(dependencies: .inMemory(library: storage))
        let game = try XCTUnwrap(m.game("tile-garden.pdf"))
        let content = PlayingWithContent(game, purpose: .change)
        XCTAssertEqual(content.core.first?.isOnlyBook, true)
        m.removeBook("tile-garden.pdf", from: "tile-garden.pdf")
        XCTAssertNotNil(m.game("tile-garden.pdf"), "Remove alone doesn't delete the game: the sheet asks first")
        m.deleteGame("tile-garden.pdf")
        XCTAssertNil(m.game("tile-garden.pdf"))
    }
}
