import XCTest
import AckshuallyCore
@testable import Ackshually

/// Deleting a game (S1) or removing a book (S13) can be undone: shake / three-finger swipe through the
/// window's `UndoManager`, or Undo on the bar at the bottom of My Games. The PDFs wait in a pending-deletion
/// folder until the app goes to the background or launches again; only then are they deleted.
@MainActor
final class UndoRemovalTests: XCTestCase {
    private var storage: InMemoryLibraryStorage!
    private var library: LibraryModel!
    private var undo: UndoManager!
    private let id = Library.sampleFileName
    private let solar = Library.sampleExpansionFileName

    override func setUp() async throws {
        storage = InMemoryLibraryStorage(folder: FileManager.default.temporaryDirectory
            .appending(path: "undo-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
        library = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()))
        library.seedSampleSet()
        undo = UndoManager()
        undo.groupsByEvent = false
    }

    /// One user action, as the run loop would group it.
    private func action(_ body: () -> Void) {
        undo.beginUndoGrouping()
        body()
        undo.endUndoGrouping()
    }

    /// A second one-book game (a copy of the sample), opened an hour earlier so it lists below the sample.
    private func addGame(_ name: String) throws {
        try FileManager.default.copyItem(at: try storage.sampleRulebook(), to: storage.url(for: name))
        var index = storage.loadIndex()
        index.record(fileName: name, title: "Tile Garden", at: .now.addingTimeInterval(-3600))
        storage.save(index)
        library = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()))
    }

    private func exists(_ fileName: String) -> Bool { FileManager.default.fileExists(atPath: storage.url(for: fileName).path) }

    private var pendingFiles: [String] {
        let pending = storage.folder.appending(path: Library.pendingDeletionFolderName, directoryHint: .isDirectory)
        return ((try? FileManager.default.contentsOfDirectory(atPath: pending.path)) ?? []).sorted()
    }

    func testDeletingAGameCanBeUndone() throws {
        let game = try XCTUnwrap(library.game(id))
        let cover = UIImage(systemName: "book")!
        library.setCover(cover, for: id)

        action { library.delete([game], undoManager: undo) }
        XCTAssertNil(library.game(id))
        XCTAssertFalse(exists(id), "the PDFs leave the library at once")
        XCTAssertEqual(pendingFiles, [id, solar].sorted(), "…but wait in the pending-deletion folder")
        XCTAssertEqual(undo.undoActionName, "Delete Game")
        XCTAssertEqual(library.undoBar?.message, "Deleted \(game.title)")

        undo.undo()
        XCTAssertEqual(library.game(id), game, "the entry and its books come back as they were")
        XCTAssertTrue(exists(id) && exists(solar))
        XCTAssertTrue(pendingFiles.isEmpty)
        XCTAssertTrue(library.covers[id] === cover, "and its cover")
        XCTAssertNil(library.undoBar)
        XCTAssertEqual(storage.loadIndex().entry(id: id), game, "saved")
    }

    func testSeveralGamesComeBackInTheirOrder() throws {
        try addGame("tile-garden.pdf")
        let before = library.games
        XCTAssertEqual(before.count, 2)
        action { library.delete(before, undoManager: undo) }
        XCTAssertTrue(library.games.isEmpty)
        XCTAssertEqual(undo.undoActionName, "Delete Games")
        XCTAssertEqual(library.undoBar?.message, "Deleted 2 Games")
        undo.undo()
        XCTAssertEqual(library.games, before)
    }

    func testFilesAreOnlyDeletedByThePurge() async throws {
        let game = try XCTUnwrap(library.game(id))
        action { library.delete([game], undoManager: undo) }
        await library.purgeRemovals()
        XCTAssertTrue(pendingFiles.isEmpty, "the purge empties the pending-deletion folder")
        XCTAssertNil(library.undoBar)
        undo.undo()
        XCTAssertNil(library.game(id), "after the purge there is nothing to bring back")
        XCTAssertFalse(exists(id))
    }

    func testLaunchPurgesWhatWasLeftPending() async throws {
        let game = try XCTUnwrap(library.game(id))
        action { library.delete([game], undoManager: undo) }
        XCTAssertFalse(pendingFiles.isEmpty)
        let next = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()), loadIndex: false)
        await next.load()
        XCTAssertTrue(pendingFiles.isEmpty)
        XCTAssertNil(next.game(id))
    }

    func testRemovingABookCanBeUndone() throws {
        let game = try XCTUnwrap(library.game(id))
        action { library.removeBook(solar, from: id, undoManager: undo) }
        XCTAssertNil(library.game(id)?.book(solar))
        XCTAssertFalse(exists(solar))
        XCTAssertEqual(pendingFiles, [solar])
        XCTAssertEqual(undo.undoActionName, "Remove Rulebook")
        XCTAssertNil(library.undoBar, "the bar is for My Games; Playing with relies on shake to undo")

        undo.undo()
        XCTAssertEqual(library.game(id), game, "the book is back in its place, with its role and tick")
        XCTAssertTrue(exists(solar))
    }

    /// The bar goes away with the next action (opening a game, adding, another delete replaces it); the undo
    /// itself stays available until the purge.
    func testTheUndoBarClearsOnTheNextAction() throws {
        try addGame("tile-garden.pdf")
        let games = library.games
        action { library.delete([games[0]], undoManager: undo) }
        XCTAssertNotNil(library.undoBar)
        library.navigationPath = [.game(id: games[1].id)]
        XCTAssertNil(library.undoBar, "opening a game clears the bar")
        undo.undo()
        XCTAssertEqual(library.games.map(\.id).sorted(), games.map(\.id).sorted(), "the undo outlives the bar")

        library.navigationPath = []
        action { library.delete([games[1]], undoManager: undo) }
        library.dismissUndoBar()
        XCTAssertNil(library.undoBar, "the bar times out")
    }

    func testUndoBarUndoesTheLatestDeletion() throws {
        let game = try XCTUnwrap(library.game(id))
        action { library.delete([game], undoManager: undo) }
        let bar = try XCTUnwrap(library.undoBar)
        library.undo(bar)
        XCTAssertEqual(library.game(id), game)
        undo.undo()
        XCTAssertEqual(library.game(id), game, "the shake undo after the bar's Undo does nothing more")
    }
}
