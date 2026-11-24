import XCTest
@testable import AckshuallyCore

final class LibraryIndexTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testRecordSortsByLastOpened() {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0)
        idx.record(fileName: "root.pdf", title: "Root", at: t0 + 60)
        idx.record(fileName: "dune.pdf", title: "Dune", at: t0 + 30)
        XCTAssertEqual(idx.entries.map(\.id), ["root.pdf", "dune.pdf", "azul.pdf"])
    }

    func testMarkOpenedMovesToTop() {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0)
        idx.record(fileName: "root.pdf", title: "Root", at: t0 + 60)
        idx.markOpened("azul.pdf", at: t0 + 120)
        XCTAssertEqual(idx.entries.first?.id, "azul.pdf")
        XCTAssertEqual(idx.entry(id: "azul.pdf")?.added, t0, "opening keeps the added date")
        idx.markOpened("missing.pdf", at: t0 + 500)
        XCTAssertEqual(idx.entries.count, 2)
    }

    func testReimportUpdatesInsteadOfDuplicating() {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "azul", at: t0)
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0 + 10)
        XCTAssertEqual(idx.entries.count, 1)
        XCTAssertEqual(idx.entries[0].title, "Azul")
        XCTAssertEqual(idx.entries[0].added, t0)
        XCTAssertEqual(idx.entries[0].lastOpened, t0 + 10)
    }

    func testRemoveAndPrune() {
        var idx = LibraryIndex()
        idx.record(fileName: "a.pdf", title: "A", at: t0)
        idx.record(fileName: "b.pdf", title: "B", at: t0)
        idx.record(fileName: "c.pdf", title: "C", at: t0)
        XCTAssertEqual(idx.remove("b.pdf")?.title, "B")
        XCTAssertNil(idx.remove("b.pdf"))
        idx.prune { $0 != "c.pdf" }
        XCTAssertEqual(idx.entries.map(\.id), ["a.pdf"])
    }

    func testTiesAreOrderedByTitle() {
        var idx = LibraryIndex()
        idx.record(fileName: "z.pdf", title: "Zeta", at: t0)
        idx.record(fileName: "a.pdf", title: "Alpha", at: t0)
        XCTAssertEqual(idx.entries.map(\.title), ["Alpha", "Zeta"])
    }

    func testFileRoundTrip() throws {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0)
        idx.record(fileName: "root.pdf", title: "Root", at: t0 + 1)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("library-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(try LibraryIndex.load(from: url), "no file yet")
        try idx.save(to: url)
        XCTAssertEqual(try LibraryIndex.load(from: url), idx)
    }

    func testCorruptFileThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("library-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try LibraryIndex.load(from: url))
    }

    // MARK: Several rulebooks (S13)

    /// A library saved before games held several books still loads: each game becomes one core book.
    func testVersion1IndexLoadsAsOneCoreBookPerGame() throws {
        let v1 = """
        {"entries":[{"added":"2026-11-20T10:00:00Z","fileName":"root-learning.pdf","lastOpened":"2026-11-23T10:00:00Z","title":"Root learning"},
                    {"added":"2026-11-20T10:00:00Z","fileName":"azul.pdf","lastOpened":"2026-11-22T10:00:00Z","title":"Azul"}],
         "version":1}
        """
        let idx = try LibraryIndex(data: Data(v1.utf8))
        XCTAssertEqual(idx.version, 2)
        XCTAssertEqual(idx.entries.map(\.id), ["root-learning.pdf", "azul.pdf"], "ids are the old file names")
        let root = try XCTUnwrap(idx.entry(id: "root-learning.pdf"))
        XCTAssertEqual(root.books, [LibraryBook(fileName: "root-learning.pdf", title: "Root learning", role: .core)])
        XCTAssertFalse(root.hasAddOns)
        XCTAssertEqual(root.booksInPlay.map(\.fileName), ["root-learning.pdf"])

        // Saved again as version 2 and read back unchanged.
        let again = try LibraryIndex(data: idx.data())
        XCTAssertEqual(again, idx)
        XCTAssertTrue(String(decoding: try idx.data(), as: UTF8.self).contains(#""books""#))
    }

    private func root() -> LibraryIndex {
        var idx = LibraryIndex()
        idx.record(fileName: "root-law.pdf", title: "Root", at: t0)
        idx.addBook(LibraryBook(fileName: "root-learning.pdf", title: "Learning to Play", role: .core), to: "root-law.pdf")
        idx.addBook(LibraryBook(fileName: "riverfolk.pdf", title: "Riverfolk", role: .addOn, ticked: true), to: "root-law.pdf")
        idx.addBook(LibraryBook(fileName: "underworld.pdf", title: "Underworld", role: .addOn, ticked: false), to: "root-law.pdf")
        return idx
    }

    func testBooksInPlayAreCoreAndTickedAddOnsInOrder() throws {
        var idx = root()
        var g = try XCTUnwrap(idx.entry(id: "root-law.pdf"))
        XCTAssertTrue(g.hasAddOns)
        XCTAssertEqual(g.booksInPlay.map(\.title), ["Root", "Learning to Play", "Riverfolk"])
        XCTAssertEqual(g.notInPlay.map(\.title), ["Underworld"])
        XCTAssertEqual(g.coverBook?.fileName, "root-law.pdf")

        idx.setTicked("underworld.pdf", in: "root-law.pdf", true)
        idx.setTicked("riverfolk.pdf", in: "root-law.pdf", false)
        idx.setTicked("root-law.pdf", in: "root-law.pdf", false)
        g = try XCTUnwrap(idx.entry(id: "root-law.pdf"))
        XCTAssertEqual(g.booksInPlay.map(\.title), ["Root", "Learning to Play", "Underworld"], "core can't be unticked")
        XCTAssertEqual(try LibraryIndex(data: idx.data()), idx, "ticks are remembered for next time")
    }

    func testRolesRenameAndRemoveKeepOneCoreBook() throws {
        var idx = root()
        let id = "root-law.pdf"
        idx.setRole("root-learning.pdf", in: id, to: .addOn)
        XCTAssertEqual(idx.entry(id: id)?.book("root-learning.pdf")?.role, .addOn)
        XCTAssertEqual(idx.entry(id: id)?.book("root-learning.pdf")?.inPlay, true, "made an add-on, still ticked")
        idx.setRole("root-law.pdf", in: id, to: .addOn)
        XCTAssertEqual(idx.entry(id: id)?.book("root-law.pdf")?.role, .core, "the last core book stays core")
        XCTAssertFalse(idx.removeBook("root-law.pdf", from: id), "nor can it be removed")
        idx.setRole("underworld.pdf", in: id, to: .core)
        XCTAssertEqual(idx.entry(id: id)?.book("underworld.pdf")?.inPlay, true)
        XCTAssertTrue(idx.removeBook("root-law.pdf", from: id), "now another core book is left")
        XCTAssertEqual(idx.entry(id: id)?.coverBook?.fileName, "underworld.pdf", "the cover is the first core book")

        idx.renameBook("riverfolk.pdf", in: id, to: "  Riverfolk Expansion ")
        XCTAssertEqual(idx.entry(id: id)?.book("riverfolk.pdf")?.title, "Riverfolk Expansion")
        idx.renameBook("riverfolk.pdf", in: id, to: "   ")
        XCTAssertEqual(idx.entry(id: id)?.book("riverfolk.pdf")?.title, "Riverfolk Expansion", "blank names are ignored")
        idx.renameGame(id, to: "Root")
        XCTAssertEqual(idx.entry(id: id)?.title, "Root")
        XCTAssertEqual(idx.entry(id: id)?.id, id, "ids never change")
    }

    func testAFileBelongsToOneGame() throws {
        var idx = root()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0 + 5)
        idx.addBook(LibraryBook(fileName: "riverfolk.pdf", title: "Riverfolk", role: .addOn), to: "azul.pdf")
        XCTAssertNil(idx.entry(id: "root-law.pdf")?.book("riverfolk.pdf"), "moved, not copied")
        XCTAssertEqual(idx.game(containing: "riverfolk.pdf")?.id, "azul.pdf")
        XCTAssertEqual(Set(idx.fileNames), ["root-law.pdf", "root-learning.pdf", "underworld.pdf", "azul.pdf", "riverfolk.pdf"])
    }

    func testPruneDropsMissingBooksAndKeepsACoreBook() throws {
        var idx = root()
        idx.prune { $0 != "root-law.pdf" && $0 != "root-learning.pdf" }
        let g = try XCTUnwrap(idx.entry(id: "root-law.pdf"))
        XCTAssertEqual(g.books.map(\.fileName), ["riverfolk.pdf", "underworld.pdf"])
        XCTAssertEqual(g.books.first?.role, .core, "the first remaining book becomes core")
        idx.prune { _ in false }
        XCTAssertTrue(idx.isEmpty, "a game with no books left is gone")
    }
}
