import XCTest
import PDFKit
import AckshuallyCore
@testable import Ackshually

/// Several rulebooks per game (S13) in the app's models: the "Playing with" list before a game with add-ons
/// opens (ticks start from last time), the joined document and its page map, a change of books applying from
/// the next question, the ＋ choice (New Game / Add to a game), and book names on cards and the pager.
@MainActor
final class RulebookSetModelTests: XCTestCase {
    private var storage: InMemoryLibraryStorage!
    private var providers: ScriptedProviders!
    private var library: LibraryModel!
    private let id = Library.sampleFileName
    private let solar = Library.sampleExpansionFileName
    private var route: GameRoute { .game(id: id) }

    override func setUp() async throws {
        storage = InMemoryLibraryStorage(folder: FileManager.default.temporaryDirectory
            .appending(path: "set-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
        providers = ScriptedProviders()
        library = LibraryModel(dependencies: .inMemory(library: storage, providers: providers))
        library.seedSampleSet()
    }

    /// Joining runs in a detached task: wait in real time, not just main-actor turns.
    private func eventually(_ what: String, timeout: Duration = .seconds(5), file: StaticString = #filePath, line: UInt = #line,
                            _ condition: () -> Bool) async {
        let clock = ContinuousClock(), end = clock.now + timeout
        while clock.now < end {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("timed out waiting for \(what)", file: file, line: line)
    }

    /// My Games → tap the game → Play.
    private func openWithPlay() async throws -> ViewerModel {
        library.navigationPath = [route]
        library.play(id)
        await eventually("the game opens") { library.path == [route] }
        return try XCTUnwrap(library.current)
    }

    // MARK: Opening

    func testAGameWithAddOnsAsksFirstAndPlayOpensTheTickedBooksJoined() async throws {
        library.navigationPath = [route]
        XCTAssertTrue(library.path.isEmpty, "not pushed yet")
        XCTAssertEqual(library.checklist?.id, id, "Playing with comes first")

        library.play(id)
        await eventually("the game opens") { library.path == [route] }
        XCTAssertNil(library.checklist)
        let v = try XCTUnwrap(library.current)
        XCTAssertEqual(v.rulebook.contents.parts.map(\.title), ["Power plant rush", "Solar Expansion"])
        XCTAssertEqual(v.rulebook.contents.parts.map(\.role), [.core, .addOn])
        XCTAssertEqual(v.rulebook.pdf.pageCount, 6, "both books, one after another")
        XCTAssertEqual(v.rulebook.matcher.pageCount, 6)
    }

    func testEveryOpenAsksAgainAndTheTicksStartFromLastTime() async throws {
        library.toggle(solar, in: id)
        let next = LibraryModel(dependencies: .inMemory(library: storage, providers: providers))
        XCTAssertEqual(next.game(id)?.book(solar)?.ticked, false, "the ticks are saved")
        library = next

        library.navigationPath = [route]
        XCTAssertEqual(library.checklist?.id, id, "asked every time: the table changes from night to night")
        library.play(id)
        XCTAssertEqual(library.path, [route], "one book in play opens at once")
        let v = try XCTUnwrap(library.current)
        XCTAssertEqual(v.rulebook.pdf.pageCount, 4)
        XCTAssertFalse(v.rulebook.contents.isJoined)
        XCTAssertEqual(v.rulebook.contents.notInPlay, ["Solar Expansion"], "still named as not in play")
    }

    func testGamesWithOnlyCoreBooksSkipTheList() async throws {
        library.setRole(solar, in: id, to: .core)
        library.navigationPath = [route]
        XCTAssertNil(library.checklist)
        await eventually("the joined game opens") { library.path == [route] }
        XCTAssertEqual(library.current?.rulebook.contents.parts.map(\.role), [.core, .core])
    }

    func testBackAndPlayAgainKeepsTheAnswer() async throws {
        let v = try await openWithPlay()
        v.present(LiveAnswer(question: "q", answer: Fixtures.solarAnswer), phase: .done)
        library.navigationPath = []
        library.navigationPath = [route]
        library.play(id)
        XCTAssertTrue(library.current === v, "same books: the session (and its answer) is resumed")
        XCTAssertNotNil(v.session.answer)
    }

    // MARK: Changing the books

    /// S13: a change applies from the next question; the answer on screen stays (with its document).
    func testChangingTheBooksAppliesFromTheNextQuestion() async throws {
        let v = try await openWithPlay()
        await ask(v, "battery with solar?", providers.provider)
        let first = try XCTUnwrap(providers.provider.requests.last)
        XCTAssertEqual(first.contents?.parts.map(\.title), ["Power plant rush", "Solar Expansion"], "the table of contents goes out")
        XCTAssertEqual(PDFDocument(data: first.pdf)?.pageCount, 6)
        providers.provider.send(contentsOf: ScriptedProvider.events(for: Fixtures.solarAnswer))
        await until("answered") { v.session.phase == .done }
        XCTAssertEqual(v.session.turns.count, 1)

        library.toggle(solar, in: id)
        library.booksChanged(id)
        XCTAssertNotNil(v.session.staged)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(v.rulebook.pdf.pageCount, 6, "the answer on screen keeps its document")
        XCTAssertNotNil(v.session.answer)

        await ask(v, "and without solar?", providers.provider)
        let second = try XCTUnwrap(providers.provider.requests.last)
        XCTAssertEqual(PDFDocument(data: second.pdf)?.pageCount, 4, "the next question uses the new books")
        XCTAssertEqual(second.contents?.notInPlay, ["Solar Expansion"])
        XCTAssertTrue(second.history.isEmpty, "a new set of books starts a new conversation")
        XCTAssertEqual(v.rulebook.pdf.pageCount, 4, "and the viewer shows them")
        XCTAssertNil(v.session.staged)
    }

    func testWithNothingOnScreenTheNewBooksShowRightAway() async throws {
        let v = try await openWithPlay()
        library.toggle(solar, in: id)
        library.booksChanged(id)
        await eventually("the new document") { v.rulebook.pdf.pageCount == 4 }
        library.booksChanged(id)
        XCTAssertNil(v.session.staged, "the same books are not staged again")
    }

    func testRenamingABookChangesTheLabelsFromTheNextQuestion() async throws {
        let v = try await openWithPlay()
        library.renameBook(solar, in: id, to: "Solar")
        library.booksChanged(id)
        await eventually("renamed") { v.rulebook.contents.parts.last?.title == "Solar" }
        XCTAssertEqual(v.rulebook.contents.reference(for: 6).label, "Solar p.2")
    }

    // MARK: Book names on screen

    func testCardsHeaderAndPagerNameTheBookWithSeveralBooks() throws {
        let v = Fixtures.setModel(card: 1)
        let card = try XCTUnwrap(v.navigator.cardItems[safe: 1])
        guard case .step(_, _, let pages, _, _) = card.content else { return XCTFail("a step card") }
        XCTAssertEqual(pages.map(\.label), ["Solar Expansion p.2", "Power Plant Rush p.3"])
        XCTAssertEqual(v.navigator.header?.pages.label, "Power Plant Rush p.3, p.4; Solar Expansion p.2")
        XCTAssertEqual(v.navigator.stepRows[1].pages.label, "Power Plant Rush p.3; Solar Expansion p.2")
        XCTAssertEqual(v.highlightChrome?.location, "Solar Expansion p.2", "the pager names the book")
        XCTAssertEqual(v.highlightChrome?.evidenceCount, 2)
        let reports = try XCTUnwrap(v.answerDetails?.evidence)
        XCTAssertEqual(reports.map(\.location), ["Power Plant Rush p.4", "Solar Expansion p.2", "Power Plant Rush p.3", "Solar Expansion p.2"],
                       "Answer Details names the book too")
        XCTAssertEqual(reports[1].page, 6, "and keeps the page of the sent document for debugging")
    }

    func testOneBookKeepsPlainPageLabels() throws {
        let v = Fixtures.model()
        v.navigator.selectStep(1)
        guard case .step(_, _, let pages, _, _)? = v.navigator.cardItems.first?.content else { return XCTFail("a step card") }
        XCTAssertEqual(pages.map(\.label), ["p.3"])
        XCTAssertNil(v.highlightChrome?.location)
        XCTAssertEqual(v.answerDetails?.evidence.first?.location, "p.3")
    }

    func testBookSwitcherJumpsToTheFirstPageOfTheBook() {
        let v = Fixtures.setModel()
        v.showBook(1)
        XCTAssertEqual(v.pdfFocus.focus?.highlight.page, 5, "Solar Expansion starts on page 5 of the joined document")
        XCTAssertEqual(v.pdfFocus.focus?.zoom, .page)
        XCTAssertTrue(v.pdfFocus.userMovedPDF, "it stays there when the sheet moves")
        v.showBook(7)
        XCTAssertEqual(v.pdfFocus.focus?.highlight.page, 5, "no such book: nothing moves")
    }

    // MARK: Adding a rulebook

    private func pickedPDF(_ name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "picked-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try FixtureRulebook.write(to: dir.appending(path: name), pages: FixtureRulebook.expansionPages)
    }

    func testAPickedPDFWaitsForNewGameOrAddToAGame() throws {
        library.importPicked(try pickedPDF("power-plant-rush-storms.pdf"))
        let p = try XCTUnwrap(library.pendingImport, "the app never guesses the grouping")
        XCTAssertEqual(p.title, "Power plant rush storms")
        XCTAssertTrue(library.path.isEmpty)

        library.importInto(id, as: .addOn)
        XCTAssertNil(library.pendingImport)
        let book = try XCTUnwrap(library.game(id)?.book(p.fileName))
        XCTAssertEqual(book.title, "Storms", "the game's name is implied")
        XCTAssertEqual(book.role, .addOn)
        XCTAssertTrue(book.ticked, "a book just added is in play")
        XCTAssertEqual(library.game(id)?.bookCountText, "3 rulebooks")
        XCTAssertNil(library.checklist, "not while the import sheet is still up")
        library.importSheetDismissed()
        XCTAssertEqual(library.checklist?.id, id, "then the game's list shows the new book")
    }

    func testNewGameFromAPickedPDFOpensItRightAway() throws {
        library.importPicked(try pickedPDF("tile-garden.pdf"))
        library.importAsNewGame()
        XCTAssertEqual(library.path, [.game(id: "tile-garden.pdf")])
        XCTAssertEqual(library.games.count, 2)
    }

    func testCancelRemovesTheCopy() async throws {
        library.importPicked(try pickedPDF("notes.pdf"))
        let copy = storage.url(for: try XCTUnwrap(library.pendingImport).fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path))
        library.cancelImport()
        await eventually("the copy is deleted") { !FileManager.default.fileExists(atPath: copy.path) }
        XCTAssertEqual(library.games.count, 1)
    }

    func testAnImportNeverReplacesAnotherBooksFile() throws {
        library.importPicked(try pickedPDF(id))
        XCTAssertEqual(library.pendingImport?.fileName, "power-plant-rush 2.pdf")
        XCTAssertEqual(PDFDocument(url: storage.url(for: id))?.pageCount, 4, "the sample's file is untouched")
        XCTAssertEqual(PDFDocument(url: storage.url(for: "power-plant-rush 2.pdf"))?.pageCount, 2)
    }

    func testWithNoGamesAPickedPDFIsANewGame() throws {
        library.delete(library.games)
        library.importPicked(try pickedPDF("azul.pdf"))
        XCTAssertNil(library.pendingImport)
        XCTAssertEqual(library.path, [.game(id: "azul.pdf")])
    }

    // MARK: Editing the books

    func testRemoveKeepsTheLastCoreBookAndDeletesTheFile() async throws {
        library.removeBook(id, from: id)
        XCTAssertNotNil(library.game(id)?.book(id), "the last core book can't be removed")
        library.removeBook(solar, from: id)
        XCTAssertNil(library.game(id)?.book(solar))
        await eventually("the file is deleted") { !FileManager.default.fileExists(atPath: storage.url(for: solar).path) }
        XCTAssertFalse(library.game(id)?.hasAddOns ?? true)
    }

    func testRowAndTitleTexts() {
        let game = library.game(id)
        XCTAssertEqual(game?.bookCountText, "2 rulebooks")
        XCTAssertEqual(game?.playingTitle, "Power plant rush · Solar Expansion")
        XCTAssertEqual(library.playingTitle(for: route), "Power plant rush · Solar Expansion")
        library.toggle(solar, in: id)
        XCTAssertEqual(library.playingTitle(for: route), "Power plant rush", "unticked add-ons aren't in the title")
        XCTAssertNil(library.playingTitle(for: .file(Fixtures.rulebookURL)), "files outside the library have a plain title")
        library.renameGame(id, to: "Power Plant Rush")
        XCTAssertEqual(library.game(id)?.title, "Power Plant Rush")
    }

    func testPlayingWithContentListsCoreAndAddOns() throws {
        let c = PlayingWithContent(try XCTUnwrap(library.game(id)), purpose: .play)
        XCTAssertEqual(c.core.map(\.title), ["Power plant rush"])
        XCTAssertEqual(c.core.first?.isLastCore, true)
        XCTAssertEqual(c.addOns.map(\.title), ["Solar Expansion"])
        XCTAssertEqual(c.addOns.first?.inPlay, true)
    }

    func testBookTitleDropsTheGameName() {
        let game = LibraryEntry(fileName: "root.pdf", title: "Root", added: .now, lastOpened: .now)
        XCTAssertEqual(LibraryModel.bookTitle("Root riverfolk learning", in: game), "Riverfolk learning")
        XCTAssertEqual(LibraryModel.bookTitle("Root: Underworld", in: game), "Underworld")
        XCTAssertEqual(LibraryModel.bookTitle("Rootbotics", in: game), "Rootbotics")
        XCTAssertEqual(LibraryModel.bookTitle("Root", in: game), "Root")
    }

    func testHighlightsOfTheOldDocumentAreDropped() {
        let store = HighlightStore(place: { Highlight(page: $0.page, kind: .wholePage) })
        let e = Evidence(page: 4, quote: "q")
        store.placeNow(e)
        XCTAssertNotNil(store[e])
        store.reset(place: { Highlight(page: $0.page, kind: .wholePage) })
        XCTAssertNil(store[e])
    }
}
