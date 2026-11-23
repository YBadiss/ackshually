import XCTest
import AckshuallyCore
@testable import Ackshually

/// Cards, branches, "More", the quote pager, highlights and the sheet rule, on one viewer session.
@MainActor
final class ViewerModelTests: XCTestCase {
    private var providers = ScriptedProviders()
    private var placer = CountingPlacer()
    private var viewer: ViewerModel!
    private var provider: ScriptedProvider { providers.provider }

    override func setUp() async throws {
        providers = ScriptedProviders()
        placer = CountingPlacer()
        viewer = makeViewer(providers, placer: placer)
    }

    private func presented() -> ViewerModel {
        viewer.present(LiveAnswer(question: batteryQuestion, answer: battery), phase: .done)
        return viewer
    }

    // MARK: Cards

    func testReaderOnLoadingCardMovesToTheNewStep() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(.firstToken, .verdict(battery.verdict), .step(index: 0, battery.steps[0]))
        await until { viewer.navigator.cards == [.step(0), .loading] }
        viewer.navigator.cardID = .loading  // swiped onto the placeholder
        provider.send(.step(index: 1, battery.steps[1]))
        await until("step 2") { viewer.session.answer?.steps.count == 2 }
        XCTAssertEqual(viewer.navigator.cardID, .step(1))
        // A reader on step 1 stays there while later steps arrive.
        viewer.navigator.select(.step(0))
        provider.send(.step(index: 2, battery.steps[2]))
        await until { viewer.session.answer?.steps.count == 3 }
        XCTAssertEqual(viewer.navigator.cardID, .step(0))
    }

    func testCardItemsAndStepRows() {
        let m = presented()
        XCTAssertEqual(m.navigator.cardItems.map(\.id), [.step(0), .step(1), .step(2)])
        XCTAssertEqual(m.navigator.cardItems[1].content,
                       .step(number: 2, title: "Battery exception", pages: [4], text: battery.steps[1].text, figure: false))
        XCTAssertEqual(m.navigator.stepRows.map(\.title), ["General rule", "Battery exception", "What's left over"])
        XCTAssertEqual(m.navigator.stepRows[2].pages, [3, 4], "sorted")
    }

    func testBranchSelectionSwitchesCardsHeaderAndRows() {
        let m = presented()
        m.navigator.select(.step(2))
        m.navigator.selectBranch(0)
        XCTAssertEqual(m.navigator.cards, [.branchStep(branch: 0, step: 0)])
        XCTAssertEqual(m.navigator.cardID, .branchStep(branch: 0, step: 0))
        XCTAssertEqual(m.navigator.header?.verdict, "Discard all 3.")
        XCTAssertEqual(m.navigator.header?.condition, "Without a Battery")
        XCTAssertEqual(m.navigator.header?.pages, [3])
        XCTAssertEqual(m.navigator.branchRows.map(\.isActive), [true])
        XCTAssertEqual(m.navigator.stepRows.count, 1)
        m.navigator.selectRow(0)
        XCTAssertEqual(m.navigator.cardID, .branchStep(branch: 0, step: 0), "a row picks that step of the branch")

        m.navigator.selectBranch(nil)  // Main Answer
        XCTAssertEqual(m.navigator.cards.count, 3)
        XCTAssertEqual(m.navigator.cardID, .step(0))
        XCTAssertEqual(m.navigator.header?.verdict, battery.verdict)
    }

    func testBranchWithoutStepsIsOneCard() {
        var a = battery
        a.branches = [Branch(condition: "Two Batteries", verdict: "Keep all 3.")]
        viewer.present(LiveAnswer(question: "q", answer: a), phase: .done)
        viewer.navigator.selectBranch(0)
        XCTAssertEqual(viewer.navigator.cardItems.map(\.content), [.branch(condition: "Two Batteries", verdict: "Keep all 3.")])
    }

    func testMoreOpensTheExpandedDetentAtThatStep() {
        let m = presented()
        XCTAssertEqual(m.detent, .medium)
        m.showMore(.step(1))
        XCTAssertEqual(m.detent, .expanded)
        XCTAssertEqual(m.navigator.expandedRow, 1)
        XCTAssertEqual(m.navigator.cardID, .step(1))
        m.navigator.clearExpandedRow()
        XCTAssertNil(m.navigator.expandedRow)
    }

    // MARK: PDF and evidence

    func testQuotePagerCyclesTheStepsPassages() {
        let m = presented()
        m.navigator.selectStep(2)  // two passages
        XCTAssertEqual(m.navigator.evidenceIndex, 0)
        XCTAssertEqual(m.pdfFocus.focus?.highlight.page, 4)
        m.pdfFocus.userMovedPDF = true
        m.nextEvidence()
        XCTAssertEqual(m.navigator.evidenceIndex, 1)
        XCTAssertEqual(m.pdfFocus.focus?.highlight.page, 3, "the PDF follows the quote")
        XCTAssertFalse(m.pdfFocus.userMovedPDF)
        m.nextEvidence()
        XCTAssertEqual(m.navigator.evidenceIndex, 0, "wraps")
        m.navigator.selectStep(0)  // one passage: the pager does nothing
        let token = m.pdfFocus.focus?.token
        m.nextEvidence()
        XCTAssertEqual(m.navigator.evidenceIndex, 0)
        XCTAssertEqual(m.pdfFocus.focus?.token, token)
    }

    func testDoubleTapZoomAndBackToStep() {
        let m = presented()
        XCTAssertEqual(m.pdfFocus.focus?.zoom, .evidence)
        m.toggleZoom()
        XCTAssertEqual(m.pdfFocus.focus?.zoom, .page)
        m.toggleZoom()
        XCTAssertEqual(m.pdfFocus.focus?.zoom, .evidence)
        m.pdfFocus.userMovedPDF = true
        let token = m.pdfFocus.focus?.token ?? 0
        m.visibleAreaChanged()
        XCTAssertEqual(m.pdfFocus.focus?.token, token, "no re-centre while the reader inspects")
        m.backToStep()
        XCTAssertFalse(m.pdfFocus.userMovedPDF)
        XCTAssertGreaterThan(m.pdfFocus.focus?.token ?? 0, token)
    }

    func testHighlightsAreResolvedOnceAndFocusedWhenTheyLand() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(contentsOf: ScriptedProvider.events(for: battery))
        await until("done") { viewer.session.phase == .done }
        let all = battery.steps.flatMap(\.evidence) + battery.branches.flatMap(\.steps).flatMap(\.evidence)
        await until("placed") { battery.steps.flatMap(\.evidence).allSatisfy { viewer.highlights[$0] != nil } }
        // Each passage arrives as .evidence, inside .step and again in .completed: placed once.
        for e in battery.steps.flatMap(\.evidence) { XCTAssertEqual(placer.count(e), 1, e.quote ?? "") }
        // Asking for them again (cards, the pager, branches) never places one twice.
        for _ in 0..<3 { all.forEach(viewer.highlights.resolve) }
        viewer.navigator.selectStep(1)
        viewer.navigator.selectStep(0)
        await until("branch placed") { all.allSatisfy { viewer.highlights[$0] != nil } }
        for e in all { XCTAssertEqual(placer.count(e), 1, e.quote ?? "") }
        XCTAssertEqual(viewer.pdfFocus.focus?.highlight.page, battery.steps[0].evidence[0].page)
        XCTAssertNotNil(viewer.currentHighlight)
    }

    func testAnswerDetailsReportEveryPassage() {
        let m = presented()
        let d = m.answerDetails
        XCTAssertEqual(d?.evidence.map(\.id), ["1.1", "2.1", "3.1", "3.2", "If Without a Battery 1.1"])
        XCTAssertEqual(d?.evidence.first?.step, "Step 1 · General rule")
        XCTAssertEqual(d?.route, .demo)
        XCTAssertEqual(m.routeLabel, "Demo answers")
        XCTAssertTrue(d?.json.contains("\"route\" : \"demo\"") ?? false)
    }

    // MARK: Sheet rule

    func testSheetNeverHidesWhileStreaming() async {
        await ask(viewer, batteryQuestion, provider)
        XCTAssertFalse(viewer.sheetVisible, "S4: the ask bar shows progress until the first token")
        var seen: [Bool] = []
        for e in ScriptedProvider.events(for: battery) {
            provider.send(e)
            await until { viewer.session.phase != .waiting }
            for _ in 0..<5 { await Task.yield() }
            seen.append(viewer.sheetVisible)
        }
        XCTAssertEqual(viewer.session.phase, .done)
        XCTAssertTrue(seen.allSatisfy { $0 }, "\(seen)")
    }

    func testClosingAndReopeningTheSheet() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(.firstToken)
        await until { viewer.sheetVisible }
        viewer.dismissSheet()
        XCTAssertFalse(viewer.sheetVisible)
        XCTAssertFalse(viewer.session.isBusy, "closing while streaming stops the answer")

        let m = presented()
        XCTAssertTrue(m.sheetVisible)
        m.dismissSheet()
        XCTAssertFalse(m.sheetVisible)
        XCTAssertNil(m.pdfFocus.focus, "the PDF goes back to the whole page")
        m.showSheet()
        XCTAssertTrue(m.sheetVisible)
        XCTAssertNotNil(m.pdfFocus.focus)

        m.detent = .expanded
        await ask(m, "again", provider)
        XCTAssertFalse(m.sheetVisible)
        XCTAssertEqual(m.detent, .medium)
        provider.send(.firstToken)
        await until { m.sheetVisible }
    }

    func testDemoNote() {
        XCTAssertFalse(presentedWith(route: .server).showsDemoNote)
        XCTAssertTrue(presented().showsDemoNote)
        providers.route = nil
        viewer = makeViewer(providers)
        XCTAssertTrue(viewer.showsDemoNote, "no credential: the ⋯ menu says demo answers")
    }

    private func presentedWith(route: AnswerRoute.Kind) -> ViewerModel {
        viewer.session.present(LiveAnswer(question: "q", answer: battery), phase: .done, route: route)
        return viewer
    }
}
