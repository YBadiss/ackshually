import XCTest
@testable import AckshuallyCore

final class LibraryIndexTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testRecordSortsByLastOpened() {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0)
        idx.record(fileName: "root.pdf", title: "Root", at: t0 + 60)
        idx.record(fileName: "dune.pdf", title: "Dune", at: t0 + 30)
        XCTAssertEqual(idx.entries.map(\.fileName), ["root.pdf", "dune.pdf", "azul.pdf"])
    }

    func testMarkOpenedMovesToTop() {
        var idx = LibraryIndex()
        idx.record(fileName: "azul.pdf", title: "Azul", at: t0)
        idx.record(fileName: "root.pdf", title: "Root", at: t0 + 60)
        idx.markOpened("azul.pdf", at: t0 + 120)
        XCTAssertEqual(idx.entries.first?.fileName, "azul.pdf")
        XCTAssertEqual(idx.entry(named: "azul.pdf")?.added, t0, "opening keeps the added date")
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
        XCTAssertEqual(idx.entries.map(\.fileName), ["a.pdf"])
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
}
