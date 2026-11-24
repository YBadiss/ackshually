import XCTest
@testable import AckshuallyCore

/// The "Add N Rulebooks" review (S14) and what Add does to the library.
final class ImportBatchTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private var root: LibraryEntry {
        LibraryEntry(id: "root-law.pdf", title: "Root", added: t0, lastOpened: t0,
                     books: [LibraryBook(fileName: "root-law.pdf", title: "Law of Root")])
    }

    private func batch(_ names: [String], preferred: String? = nil) -> ImportBatch {
        ImportBatch(files: names.map { ($0, $0.replacingOccurrences(of: ".pdf", with: "")) }, preferredGameID: preferred)
    }

    private func suggestion(_ file: String, _ target: RulebookSorter.Suggestion.Target, _ role: BookRole = .addOn,
                            title: String? = nil, skip: Bool = false) -> RulebookSorter.Suggestion {
        .init(fileName: file, target: target, role: role, title: title ?? file, reason: "r", notARulebook: skip)
    }

    func testStartsSortingThenGroupsBySuggestion() {
        var b = batch(["learn.pdf", "river.pdf", "azul.pdf", "dune.pdf", "score.pdf", "mystery.pdf"])
        XCTAssertTrue(b.isSorting)
        XCTAssertEqual(b.origin, .sorting)
        b.apply([
            suggestion("learn.pdf", .existing(id: "root-law.pdf"), .core, title: "Learning to Play"),
            suggestion("river.pdf", .existing(id: "root-law.pdf"), title: "Riverfolk"),
            suggestion("azul.pdf", .new(name: "Azul"), .core),
            suggestion("dune.pdf", .new(name: "azul"), .addOn),  // same new game, other case
            suggestion("score.pdf", .new(name: "Azul"), skip: true),
        ], games: [root])
        XCTAssertFalse(b.isSorting)
        XCTAssertEqual(b.origin, .suggested)
        XCTAssertEqual(b.groups.map(\.name), ["Root", "Azul", "mystery"])
        XCTAssertEqual(b.groups[0].target, .existing("root-law.pdf"))
        XCTAssertEqual(b.groups[0].books.map(\.title), ["Learning to Play", "Riverfolk"])
        XCTAssertEqual(b.groups[1].books.map(\.fileName), ["azul.pdf", "dune.pdf"])
        XCTAssertEqual(b.groups[2].books.first?.role, .core, "a file without a suggestion is its own game")
        XCTAssertEqual(b.skipped.map(\.fileName), ["score.pdf"])
        XCTAssertEqual(b.bookCount, 5)
        XCTAssertEqual(b.newGameCount, 2)
        XCTAssertEqual(Set(b.fileNames).count, 6)
    }

    func testUnsortedIsOneGamePerFileOrThePreferredGame() {
        var b = batch(["a.pdf", "b.pdf"])
        b.leaveUnsorted(games: [root])
        XCTAssertEqual(b.origin, .unsorted)
        XCTAssertEqual(b.groups.map(\.name), ["a", "b"])
        XCTAssertTrue(b.groups.allSatisfy { $0.isNew && $0.books.map(\.role) == [.core] })

        var fromRoot = batch(["a.pdf", "b.pdf"], preferred: "root-law.pdf")
        fromRoot.leaveUnsorted(games: [root])
        XCTAssertEqual(fromRoot.groups.count, 1)
        XCTAssertEqual(fromRoot.groups[0].target, .existing("root-law.pdf"))
        XCTAssertEqual(fromRoot.groups[0].books.map(\.role), [.addOn, .addOn])
    }

    func testMoveBetweenGroupsNewGameAndSkip() throws {
        var b = batch(["a.pdf", "b.pdf", "c.pdf"])
        b.apply([suggestion("a.pdf", .new(name: "A"), .core), suggestion("b.pdf", .new(name: "A")),
                 suggestion("c.pdf", .new(name: "C"), .core)], games: [])
        let a = try XCTUnwrap(b.group(containing: "a.pdf")).id
        let c = try XCTUnwrap(b.group(containing: "c.pdf")).id
        // Move the only book of C into A, before b: C disappears.
        b.move("c.pdf", toGroup: a, before: "b.pdf")
        XCTAssertNil(b.group(c))
        XCTAssertEqual(b.group(a)?.books.map(\.fileName), ["a.pdf", "c.pdf", "b.pdf"])
        // Moving A's only core out leaves a core behind.
        b.setRole("c.pdf", .addOn)
        let newID = try XCTUnwrap(b.moveToNewGame("a.pdf"))
        XCTAssertEqual(b.group(newID)?.books.map(\.role), [.core])
        XCTAssertEqual(b.group(a)?.books.first?.role, .core, "the first remaining book becomes core")
        // Into an existing game: an add-on.
        b.move("b.pdf", toGame: root)
        XCTAssertEqual(b.group(containing: "b.pdf")?.target, .existing("root-law.pdf"))
        XCTAssertEqual(b.group(containing: "b.pdf")?.books.first?.role, .addOn)
        b.skip("b.pdf")
        XCTAssertNil(b.group(containing: "b.pdf"))
        XCTAssertEqual(b.skipped.map(\.fileName), ["b.pdf"])
        // Back from Skipped.
        b.move("b.pdf", toGroup: newID)
        XCTAssertTrue(b.skipped.isEmpty)
    }

    func testRenameAndLastCore() throws {
        var b = batch(["a.pdf", "x.pdf"])
        b.apply([suggestion("a.pdf", .new(name: "A"), .core), suggestion("x.pdf", .existing(id: "root-law.pdf"))], games: [root])
        let a = try XCTUnwrap(b.group(containing: "a.pdf")).id
        XCTAssertTrue(b.isLastCore("a.pdf"))
        b.setRole("a.pdf", .addOn)
        XCTAssertEqual(b.group(a)?.books.first?.role, .core, "a new game keeps a core book")
        b.renameGroup(a, to: "  Alpha ")
        XCTAssertEqual(b.group(a)?.name, "Alpha")
        b.renameGroup("game:root-law.pdf", to: "Not Root")
        XCTAssertEqual(b.group("game:root-law.pdf")?.name, "Root", "existing games are renamed in Playing with")
        b.renameBook("x.pdf", to: "Riverfolk")
        b.renameBook("x.pdf", to: "  ")
        XCTAssertEqual(b.group(containing: "x.pdf")?.books.first?.title, "Riverfolk")
    }

    // MARK: Library

    func testAddBatchToLibrary() {
        var idx = LibraryIndex(entries: [root])
        var b = batch(["learn.pdf", "azul.pdf", "azul-faq.pdf", "score.pdf"])
        b.apply([suggestion("learn.pdf", .existing(id: "root-law.pdf"), .core, title: "Learning to Play"),
                 suggestion("azul.pdf", .new(name: "Azul"), .addOn), suggestion("azul-faq.pdf", .new(name: "Azul"), .addOn),
                 suggestion("score.pdf", .new(name: "Azul"), skip: true)], games: [root])
        let created = idx.add(b, at: t0 + 60)
        XCTAssertEqual(created, ["azul.pdf"])
        XCTAssertEqual(idx.entries.map(\.id), ["azul.pdf", "root-law.pdf"], "new games come first")
        XCTAssertEqual(idx.entry(id: "azul.pdf")?.books.map(\.role), [.core, .addOn], "a new game gets a core book")
        XCTAssertEqual(idx.entry(id: "root-law.pdf")?.books.map(\.title), ["Law of Root", "Learning to Play"])
        XCTAssertNil(idx.game(containing: "score.pdf"))
    }

    func testAddToAGameDeletedMeanwhileMakesANewGame() {
        var idx = LibraryIndex()
        var b = batch(["x.pdf"])
        b.apply([suggestion("x.pdf", .existing(id: "root-law.pdf"))], games: [root])
        XCTAssertEqual(idx.add(b, at: t0), ["x.pdf"])
        XCTAssertEqual(idx.entry(id: "x.pdf")?.title, "Root")
        XCTAssertEqual(idx.entry(id: "x.pdf")?.books.first?.role, .core)
    }

    func testDeleteSeveralRemoveAllAndOnlyBook() {
        var idx = LibraryIndex()
        for n in ["a", "b", "c"] { idx.record(fileName: "\(n).pdf", title: n.uppercased(), at: t0) }
        idx.addBook(LibraryBook(fileName: "a2.pdf", title: "A2", role: .addOn), to: "a.pdf")
        XCTAssertTrue(idx.entry(id: "b.pdf")!.isOnlyBook("b.pdf"))
        XCTAssertFalse(idx.entry(id: "a.pdf")!.isOnlyBook("a.pdf"))
        XCTAssertFalse(idx.removeBook("b.pdf", from: "b.pdf"), "the only book goes with its game")
        let removed = idx.remove(["a.pdf", "missing", "b.pdf"])
        XCTAssertEqual(removed.map(\.id).sorted(), ["a.pdf", "b.pdf"])
        XCTAssertEqual(removed.flatMap { $0.books.map(\.fileName) }.sorted(), ["a.pdf", "a2.pdf", "b.pdf"])
        XCTAssertEqual(idx.entries.map(\.id), ["c.pdf"])
        XCTAssertEqual(idx.removeAll().map(\.id), ["c.pdf"])
        XCTAssertTrue(idx.isEmpty)
    }
}
