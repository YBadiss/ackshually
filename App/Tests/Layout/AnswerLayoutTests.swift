import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// The answer column's layout (S4–S9), hosted in-process at an iPhone 18 Pro width: margins, what each
/// detent shows, cards and their text, the verdict cap, branch rows. Frames are read from the
/// accessibility tree by identifier, as the UI tests did, in milliseconds instead of an app launch.
/// What only the real system sheet shows (detents, dragging, the sheet holding still while an answer
/// streams) stays in `AnswerSheetUITests`.
@MainActor
final class AnswerLayoutTests: XCTestCase {
    private static let phone = CGSize(width: 402, height: 874)
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    /// The answer column as the sheet shows it at `detent`.
    private func column(_ model: ViewerModel, _ placement: AnswerPlacement, typeSize: DynamicTypeSize = .large,
                        onMetrics: @escaping (AnswerMetrics) -> Void = { _ in }) async -> HostedView {
        let h = HostedView(size: Self.phone, typeSize: typeSize) {
            AnswerContent(model: model, voice: AskController(), placement: placement, onMetrics: onMetrics)
                .themeBackground(\.sheet)
        }
        host = h
        await h.settle()
        return h
    }

    private func presented(_ answer: Answer = battery) -> ViewerModel {
        let m = makeViewer()
        m.present(LiveAnswer(question: batteryQuestion, answer: answer), phase: .done)
        return m
    }

    private func answer(verdict: String = "Keep 2, discard 1.", steps: [(String, String)],
                        branches: [Branch] = []) -> Answer {
        Answer(restatedQuestion: "What happens to unused energy?", verdict: verdict, confidence: .stated, branches: branches,
               assumptions: [], steps: steps.map { Step(title: $0.0, text: $0.1, evidence: [Evidence(page: 3, quote: "you must discard all unused energy")]) },
               needsWeb: false)
    }

    private func unwrap(_ h: HostedView, _ id: String, file: StaticString = #filePath, line: UInt = #line) throws -> CGRect {
        try XCTUnwrap(h.frame(id), "\(id) not on screen", file: file, line: line)
    }

    // MARK: Margins

    /// Spec §3: content keeps `sheetMargin` (20 pt) off the sheet's sides and `sheetTop` (28 pt) under
    /// its top edge (the grabber), so the close button stays out of the rounded corner, at every detent.
    /// Was 15 pt from the top before the sheet-breathing fix.
    func testSheetContentHasStandardMargins() async throws {
        let edge: CGFloat = 20, top: CGFloat = 28
        for detent in [SheetDetent.collapsed, .medium, .expanded] {
            let h = await column(presented(), .sheet(detent))
            let width = h.window.bounds.width
            let verdict = try unwrap(h, "verdict"), close = try unwrap(h, "closeAnswer")
            XCTAssertGreaterThanOrEqual(verdict.minY, top, "verdict clears the grabber (\(detent))")
            XCTAssertGreaterThanOrEqual(close.minY, edge, "close button clears the top edge (\(detent))")
            XCTAssertGreaterThanOrEqual(width - close.maxX, edge, "close button clears the corner (\(detent))")
            XCTAssertGreaterThanOrEqual(verdict.minX, edge, "verdict margin (\(detent))")
            guard detent != .collapsed else { continue }
            // Medium shows the step cards; expanded unfolds them into the step list.
            let steps = try unwrap(h, detent == .medium ? "stepCard" : "stepRow-0")
            XCTAssertGreaterThanOrEqual(steps.minX, edge, "steps margin (\(detent))")
            XCTAssertGreaterThanOrEqual(try unwrap(h, "answerFooter").minX, edge, "follow-up field margin (\(detent))")
            XCTAssertGreaterThanOrEqual(width - (try unwrap(h, "thumbsDown")).maxX, edge, "thumbs margin (\(detent))")
            h.close()
        }
    }

    // MARK: What each detent shows

    /// Collapsed (S7): verdict and proof line only; the detent (header bottom) includes the whole proof
    /// line, and nothing below it is on screen or reachable by VoiceOver.
    func testCollapsedShowsWholeHeaderOnly() async throws {
        var metrics = AnswerMetrics()
        let h = await column(presented(), .sheet(.collapsed)) { metrics = $0 }
        let proof = try unwrap(h, "proofLine")
        XCTAssertGreaterThanOrEqual(metrics.collapsed, proof.maxY, "the collapsed detent cuts through the proof line")
        for hidden in ["stepCard", "cardDots", "answerFooter", "branch-0"] {
            XCTAssertNil(h.frame(hidden), "\(hidden) shows on the collapsed sheet")
        }
    }

    /// Medium (S5) ends on a content boundary: the sheet is the medium height plus the home-indicator
    /// inset, and the scroll content draws under the indicator, so whatever follows the branch rows
    /// ("Assumes", the demo note) must be hidden at medium, not left half-cut by the sheet's edge
    /// (13 mini and 18 Pro, 2026-11-28: the top of "ASSUMES" showed under the If… row).
    func testMediumDetentEndsAfterTheBranchRows() async throws {
        let homeIndicator: CGFloat = 34
        for size in [CGSize(width: 375, height: 812), Self.phone] {
            for typeSize in [DynamicTypeSize.large, .accessibility3] {
                var metrics = AnswerMetrics()
                let m = presented()
                let h = HostedView(size: size, typeSize: typeSize) {
                    AnswerContent(model: m, voice: AskController(), placement: .sheet(.medium), onMetrics: { metrics = $0 })
                        .themeBackground(\.sheet)
                }
                await h.settle()
                let edge = metrics.medium + homeIndicator
                let branch = try unwrap(h, "branch-0")
                XCTAssertLessThanOrEqual(branch.maxY, metrics.medium, "medium includes the branch rows (\(size), \(typeSize))")
                for below in ["assumptions", "demoNote"] {
                    if let f = h.frame(below) {
                        XCTAssertGreaterThanOrEqual(f.minY, edge, "\(below) at \(f.minY) shows under the medium edge \(edge) (\(size), \(typeSize))")
                    }
                }
                h.close()
            }
        }
        // Expanded still shows them.
        let h = await column(presented(), .sheet(.expanded))
        XCTAssertNotNil(h.frame("assumptions"), "expanded shows Assumes")
    }

    /// Medium (S5): the follow-up field and thumbs sit in their own row under the shelf, once.
    func testFollowUpRowSitsUnderTheShelf() async throws {
        let h = await column(presented(), .sheet(.medium))
        XCTAssertGreaterThan(try unwrap(h, "followUpField").minY, try unwrap(h, "carousel").maxY)
        XCTAssertEqual(h.frames("thumbsUp").count, 1)
        XCTAssertTrue(try unwrap(h, "answerFooter").contains(try unwrap(h, "thumbsUp")))
    }

    /// Expanded (S9): the cards unfold into the step list in place, and each part shows once (the
    /// carousel, follow-up field and thumbs used to appear again further down). A branch whose verdict
    /// is a whole sentence puts it under the condition instead of one letter per line beside it.
    func testExpandedShowsEachPartOnceAndLongBranchVerdictStacks() async throws {
        let a = answer(verdict: "Unused energy is lost.", steps: [("Rule", "Unused energy is discarded."), ("Timing", "At the end of the round.")],
                       branches: [Branch(condition: "If you meant the bonus tiles rather than the energy cubes",
                                         verdict: "Bonus tiles are never discarded; they stay in front of you and count at the end of the game.",
                                         steps: [])])
        let h = await column(presented(a), .sheet(.expanded))
        XCTAssertNotNil(h.frame("stepRow-1"))
        XCTAssertNil(h.frame("carousel"), "expanded shows the step list instead of the cards")
        XCTAssertEqual(h.frames("followUpField").count, 1)
        XCTAssertEqual(h.frames("thumbsUp").count, 1)
        let branch = try unwrap(h, "branch-0")
        // Stacked: condition (2 lines) + verdict (about 3); a one-letter column ran to 20+ lines.
        XCTAssertLessThan(branch.height, branch.width * 0.75, "branch row \(branch)")
    }

    // MARK: Cards

    private static let longText = Array(repeating: "A player who owns a Battery keeps up to 2 unused energy at the end of the turn instead of discarding them, and any additional energy is discarded as normal.", count: 3).joined(separator: " ")

    /// Step card text never renders outside its card (owner's Azul test), at default and accessibility
    /// text sizes; all cards share one height and long text offers "More".
    func testCardTextStaysInsideCard() async throws {
        let a = answer(steps: [("Short", "Unused energy is discarded."), ("Long", Self.longText),
                               ("Medium", "Anything above 2 is still discarded, so 1 of your 3 energy goes back to the supply.")])
        for size in [DynamicTypeSize.large, .accessibility3] {
            let h = await column(presented(a), .sheet(.medium), typeSize: size)
            let cards = h.frames("stepCard")
            XCTAssertEqual(cards.count, 3, "\(size)")
            XCTAssertEqual(Set(cards.map { Int($0.height.rounded()) }).count, 1, "all cards share one height (\(size)): \(cards)")
            for text in h.frames("stepCardText") {
                let card = try XCTUnwrap(cards.first { $0.minX <= text.midX && text.midX <= $0.maxX })
                XCTAssertTrue(card.insetBy(dx: -1, dy: -1).contains(text), "text \(text) outside card \(card) at \(size)")
            }
            XCTAssertFalse(h.frames("cardMore").isEmpty, "the long step offers More (\(size))")
            h.close()
        }
    }

    /// While an answer streams the loading card holds a full card's height; once complete the cards fit
    /// their content again (equal height, well under the placeholder).
    func testCardsFitContentAfterStreaming() async throws {
        let providers = ScriptedProviders()
        let viewer = makeViewer(providers)
        let a = answer(verdict: "Discard it.", steps: [("Rule", "Unused energy is discarded."), ("Battery", "A Battery keeps 2.")])
        await ask(viewer, "What happens to unused energy?", providers.provider)
        let events = ScriptedProvider.events(for: a)
        let firstStep = try XCTUnwrap(events.firstIndex { if case .step = $0 { true } else { false } })
        for e in events[...firstStep] { providers.provider.send(e) }
        await until { viewer.navigator.cards.count == 2 }
        let h = await column(viewer, .sheet(.medium))
        let loading = try XCTUnwrap(h.elements.first { $0.identifier == "stepCard" && $0.label == "Next step loading" })
        for e in events[(firstStep + 1)...] { providers.provider.send(e) }
        await until { !viewer.session.isBusy }
        await h.settle()
        let cards = h.frames("stepCard")
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(Set(cards.map { Int($0.height.rounded()) }).count, 1, "equal heights: \(cards)")
        XCTAssertLessThan(cards[0].height, loading.frame.height * 0.75,
                          "card \(cards[0].height) fits its 1-line text, not the placeholder \(loading.frame.height)")
    }

    // MARK: Header

    /// A long verdict is capped at three lines on the sheet (owner: "5 bold lines"); expanded shows it
    /// all; VoiceOver always gets the whole verdict.
    func testLongVerdictIsCappedUntilExpanded() async throws {
        func header(expanded: Bool) async throws -> (verdict: HostedView.Element, proof: CGRect) {
            let h = HostedView(size: Self.phone) {
                AnswerHeader(content: Fixtures.headerLongVerdict, showsQuestion: expanded).padding(20)
            }
            defer { h.close() }
            await h.settle()
            return (try XCTUnwrap(h.element("verdict")), try unwrap(h, "proofLine"))
        }
        let capped = try await header(expanded: false), full = try await header(expanded: true)
        XCTAssertEqual(capped.verdict.label, Fixtures.headerLongVerdict.verdict)
        // Three title3 lines are well under 4.2 × the proof line's height.
        XCTAssertLessThan(capped.verdict.frame.height, capped.proof.height * 4.2)
        XCTAssertGreaterThan(full.verdict.frame.height, capped.verdict.frame.height * 1.3, "expanded shows the whole verdict")
    }

    /// Failures: a rejected token offers Open Settings; rate limits offer only Try Again.
    func testFailureHeaderOffersSettingsOnlyWhenSettingsFixesIt() async throws {
        let cases: [(String, Bool)] = [(Fixtures.tokenRejected, true), (Fixtures.dailyLimit, false)]
        for (message, opensSettings) in cases {
            let content = HeaderContent(state: .failed(AnswerFailure(message: message, opensSettings: opensSettings)), question: "Can I keep energy?")
            let h = HostedView(size: Self.phone) { AnswerHeader(content: content, onSettings: {}).padding(20) }
            await h.settle()
            XCTAssertEqual(h.element("failureMessage")?.label, message)
            XCTAssertEqual(h.frame("failureSettings") != nil, opensSettings, message)
            XCTAssertTrue(h.elements.contains { $0.label == "Try Again" }, message)
            h.close()
        }
    }
}
