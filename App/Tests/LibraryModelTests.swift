import XCTest
import AckshuallyCore
@testable import Ackshually

/// My Games' per-game viewer sessions (S1, groundwork for S11 history): going back and re-opening a game
/// keeps its answer; the last few games keep theirs; deleting or re-importing a game drops it.
@MainActor
final class LibraryModelTests: XCTestCase {
    private var storage: InMemoryLibraryStorage!
    private var library: LibraryModel!

    override func setUp() async throws {
        storage = InMemoryLibraryStorage(folder: FileManager.default.temporaryDirectory
            .appending(path: "library-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
        library = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()))
    }

    /// Adds `n` games (copies of the sample) without opening them.
    private func addGames(_ n: Int) throws -> [GameRoute] {
        let sample = try storage.sampleRulebook()
        var index = storage.loadIndex()
        let routes = try (1...n).map { i -> GameRoute in
            let name = "game-\(i).pdf"
            try FileManager.default.copyItem(at: sample, to: storage.url(for: name))
            index.record(fileName: name, title: "Game \(i)")
            return .game(id: name)
        }
        storage.save(index)
        library = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()))
        return routes
    }

    private func open(_ route: GameRoute) -> ViewerModel? {
        library.navigationPath = [route]
        return library.current
    }

    private func back() { library.navigationPath = [] }

    /// Launch reads the index in the background: the model starts empty and unloaded (the list shows
    /// nothing rather than "No Games Yet"), then `load()` brings the saved games in.
    func testLaunchLoadsTheIndexInTheBackground() async throws {
        _ = try addGames(2)
        let launching = LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()), loadIndex: false)
        XCTAssertFalse(launching.isLoaded)
        XCTAssertTrue(launching.games.isEmpty)
        await launching.load()
        XCTAssertTrue(launching.isLoaded)
        XCTAssertEqual(launching.games.count, 2)
    }

    func testReopeningAGameKeepsItsSession() throws {
        let games = try addGames(2)
        let a = try XCTUnwrap(open(games[0]))
        a.present(LiveAnswer(question: "q", answer: battery), phase: .done)
        back()
        XCTAssertNil(library.current)
        XCTAssertTrue(open(games[0]) === a, "back + tap the same game resumes its answer")
        XCTAssertNotNil(a.session.answer)

        back()
        let b = try XCTUnwrap(open(games[1]))
        XCTAssertFalse(b === a, "each game has its own session")
        XCTAssertNil(b.session.answer)
        back()
        XCTAssertTrue(open(games[0]) === a, "another game in between keeps it too")
        XCTAssertEqual(library.games.first?.id, "game-1.pdf", "opening bumps the game to the top")
    }

    func testOnlyTheLastFewGamesKeepTheirSession() throws {
        let games = try addGames(LibraryModel.sessionLimit + 1)
        let first = try XCTUnwrap(open(games[0]))
        for g in games.dropFirst() { back(); _ = open(g) }
        XCTAssertEqual(library.sessions.count, LibraryModel.sessionLimit)
        XCTAssertNil(library.session(for: games[0]))
        back()
        XCTAssertFalse(open(games[0]) === first, "the oldest one starts over")
    }

    func testDeletingAGameDropsItsSession() throws {
        let games = try addGames(1)
        _ = open(games[0])
        back()
        library.delete(library.games)
        XCTAssertNil(library.session(for: games[0]))
        XCTAssertTrue(library.games.isEmpty)
    }

    /// A full swipe on a game with several books still asks first (#25: every game allows a full swipe now);
    /// the confirmation's button names the action.
    func testFullSwipeOnAMultiBookGameAsksFirst() {
        let library = LibraryFixtures.model()
        let woodland = library.games.first { $0.books.count > 1 }!
        library.requestDelete([woodland])
        XCTAssertNotNil(library.game(woodland.id), "nothing deleted before the confirmation")
        XCTAssertEqual(library.pendingDeletion?.question, "Delete Woodland Court and its 7 rulebooks?")
        XCTAssertEqual(library.pendingDeletion?.confirmTitle, "Delete Game")
        library.pendingDeletion = nil
        library.requestDelete(Array(library.games.prefix(3)))
        XCTAssertEqual(library.pendingDeletion?.confirmTitle, "Delete 3 Games")
    }

    func testReimportReplacesTheSession() throws {
        library.addSample()
        let first = try XCTUnwrap(library.current)
        back()
        library.addSample()
        XCTAssertFalse(library.current === first, "a re-import reloads the file")
        XCTAssertEqual(library.games.count, 1)
        XCTAssertEqual(library.sessions.count, 1)
    }

    func testUnreadableFileShowsAnErrorAndStaysOnTheList() throws {
        let url = storage.url(for: "broken.pdf")
        try Data("not a pdf".utf8).write(to: url)
        library.openTransient(url)
        XCTAssertEqual(library.error, "Couldn't open broken.pdf as a PDF.")
        XCTAssertTrue(library.path.isEmpty)
    }

    // MARK: Adding, deleting, relaunching (were LibraryUITests)

    /// A fresh model over the same storage: what the next launch reads.
    private func relaunch() -> LibraryModel {
        LibraryModel(dependencies: .inMemory(library: storage, providers: ScriptedProviders()))
    }

    func testTrySampleAddsTheGameAndOpensIt() throws {
        library.addSample()
        let name = try storage.sampleRulebook().lastPathComponent
        XCTAssertEqual(library.path, [.game(id: name)], "opens the new game right away")
        XCTAssertNotNil(library.current)
        XCTAssertEqual(library.games.map(\.id), [name], "and it is in the list behind it")
        XCTAssertEqual(library.games.first?.title, "Power plant rush")
    }

    func testRelaunchOpensOnTheListWithTheGame() {
        library.addSample()
        let next = relaunch()
        XCTAssertTrue(next.path.isEmpty, "the app opens on the list, not the last rulebook")
        XCTAssertEqual(next.games.count, 1)
    }

    func testDeletedGameIsGoneAfterRelaunch() {
        library.addSample()
        back()
        library.delete(library.games)
        XCTAssertTrue(relaunch().games.isEmpty)
    }

    func testLaunchArgumentDocumentDoesNotJoinTheList() throws {
        library.openSampleTransient()
        XCTAssertEqual(library.path, [.file(try storage.sampleRulebook())])
        XCTAssertTrue(library.games.isEmpty, "-sample is not added to My Games")
    }
}
