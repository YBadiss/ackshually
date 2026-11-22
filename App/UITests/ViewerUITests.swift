import XCTest

/// Drives the M2 interactions on the sample rulebook with demo answers (no API key), on the
/// native UI: system sheet with detents, inspector on wide screens, glass ask field.
/// Set SCREENSHOT_DIR in the test environment to save PNGs.
@MainActor
final class ViewerUITests: XCTestCase {
    private let app = XCUIApplication()

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ args: [String]) {
        continueAfterFailure = false
        app.launchArguments = ["-sample", "YES", "-demo", "YES"] + args
        app.launch()
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name; a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// Drags from an element to a point at `y` (fraction of the window height).
    private func drag(_ e: XCUIElement, toY y: CGFloat) {
        let start = e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Writes a spec §4 answer for `-demoAnswer` (the sample rulebook's pages 3–4 hold the quotes).
    private func demoAnswer(verdict: String, steps: [(title: String, text: String, page: Int, quote: String)]) throws -> String {
        let json: [String: Any] = [
            "restated_question": "What happens to unused energy?", "verdict": verdict, "confidence": "stated",
            "steps": steps.map { ["title": $0.title, "text": $0.text, "evidence": [["page": $0.page, "quote": $0.quote, "box": NSNull()]]] },
            "branches": [], "assumptions": [], "needs_web": false,
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url.path
    }

    private static let longText = Array(repeating: "A player who owns a Battery keeps up to 2 unused energy at the end of the turn instead of discarding them, and any additional energy is discarded as normal.", count: 3).joined(separator: " ")
    private static let goodQuote = "you must discard all unused energy"
    private static let missingQuote = "players may trade energy freely during the auction phase of the game"

    private var dots: XCUIElement { app.descendants(matching: .any)["cardDots"].firstMatch }
    private var verdict: XCUIElement { app.staticTexts["verdict"] }

    private func waitForCard(_ label: String, timeout: TimeInterval = 3) -> Bool {
        let p = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: dots)], timeout: timeout) == .completed
    }

    func testStreamingThenStepping() {
        launch(["-ask", "what happens to my energy at end of turn if I have the battery"])
        // S3 → S4: the ask field becomes "Reading the rulebook…" + Stop; the sheet rises on the first token.
        XCTAssertTrue(app.buttons["stop"].waitForExistence(timeout: 3))
        shot("s3-waiting")
        XCTAssertTrue(verdict.waitForExistence(timeout: 8))
        shot("s4-streaming")
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 6), "Stop turns into Close when done")
        shot("s5-step1")
        XCTAssertTrue(waitForCard("Card 1 of 3"))
        carousel.swipeLeft()
        // A simulator swipe right after the stream settles occasionally doesn't register: retry once.
        if !waitForCard("Card 2 of 3") { carousel.swipeLeft() }
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        shot("s6-step2")
        // Tap the right peek → next card.
        carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertTrue(waitForCard("Card 3 of 3"))
        shot("s6-step3")
    }

    func testInspectBackToStepAndDoubleTap() {
        launch(["-present", "YES", "-card", "1"])
        let window = app.windows.firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        sleep(1)
        // S8: the PDF stays pannable under the sheet (background interaction) → Back to Step.
        XCTAssertFalse(app.buttons["backToStep"].exists)
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        from.press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        XCTAssertTrue(app.buttons["backToStep"].waitForExistence(timeout: 2))
        shot("s8-inspect")
        app.buttons["backToStep"].tap()
        XCTAssertTrue(app.buttons["backToStep"].waitForNonExistence(timeout: 2))
        // Tapping the PDF never changes steps.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        // Double-tap: evidence ↔ full page.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).doubleTap()
        sleep(1)
        shot("s8-full-page")
    }

    func testBranchAndDetents() {
        launch(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        // S9: a branch row switches the cards to the branch's own steps; Main Answer returns.
        app.buttons["branch-0"].tap()
        XCTAssertTrue(app.buttons["mainAnswer"].waitForExistence(timeout: 2))
        XCTAssertTrue(waitForCard("Card 1 of 1"))
        XCTAssertEqual(verdict.label, "Discard all 3.")
        shot("s9-branch")
        app.buttons["mainAnswer"].tap()
        XCTAssertTrue(waitForCard("Card 1 of 3"))
        // S7: drag the system sheet down to the collapsed detent: the cards go off screen.
        drag(verdict, toY: 0.98)
        sleep(1)
        XCTAssertTrue(verdict.isHittable)
        XCTAssertFalse(app.buttons["branch-0"].isHittable)
        shot("s7-collapsed")
        // Drag up → medium, again → large (S9: all steps).
        drag(verdict, toY: 0.55)
        sleep(1)
        XCTAssertTrue(app.buttons["branch-0"].isHittable)
        drag(verdict, toY: 0.05)
        sleep(1)
        XCTAssertTrue(app.buttons["stepRow-2"].isHittable)
        shot("s9-expanded")
        // Tapping a step row jumps back to that card at medium.
        app.buttons["stepRow-1"].tap()
        XCTAssertTrue(waitForCard("Card 2 of 3"))
    }

    func testFollowUpKeepsContext() {
        launch(["-present", "YES"])
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        for _ in 0..<2 { carousel.swipeLeft(); usleep(400_000) }
        // The last card is the last step: no closing "Result" card repeating the verdict.
        XCTAssertTrue(waitForCard("Card 3 of 3"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "stepCard").allElementsBoundByIndex.contains { $0.label.hasPrefix("Result") })
        // Follow-up and thumbs live in their own row under the shelf.
        let field = app.textFields["followUpField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(identifier: "thumbsUp").allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertGreaterThan(field.frame.minY, carousel.frame.maxY)
        shot("s6-last-card")
        field.tap()
        field.typeText("And with two Batteries?\n")
        XCTAssertTrue(app.buttons["stop"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 12))
    }

    func testCloseThenAskAgainAndLandscapeInspector() {
        launch(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        app.buttons["closeAnswer"].tap()
        XCTAssertTrue(app.textFields["askField"].waitForExistence(timeout: 3))
        // ⋯ → Show Answer brings it back.
        // The ⋯ is the system toolbar overflow menu.
        app.navigationBars.buttons["More"].firstMatch.tap()
        app.buttons["Show Answer"].tap()
        XCTAssertTrue(verdict.waitForExistence(timeout: 3))
        // Phone landscape: the answer moves to the inspector column (no sheet).
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        shot("wide-landscape")
        XCTAssertTrue(verdict.isHittable)
        XCTAssertTrue(app.buttons["toggleAnswer"].exists)
    }

    // MARK: Regressions found by hand on 2026-11-21

    /// A rulebook opens with the whole page visible, not zoomed to page width.
    func testRulebookOpensOnWholePage() {
        launch([])
        let pdf = app.descendants(matching: .any)["pdfView"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertEqual(pdf.value as? String, "Whole page")
        // Once an answer focuses evidence it zooms; closing the answer goes back to the whole page.
        app.terminate()
        launch(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue((pdf.value as? String ?? "").hasPrefix("Zoomed"))
        app.buttons["closeAnswer"].tap()
        XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Whole page"), object: pdf)], timeout: 3) == .completed)
    }

    /// Collapsed sheet (S7): verdict and proof line fully on screen, nothing cut off below them.
    func testCollapsedShowsWholeHeaderOnly() {
        launch(["-present", "YES", "-detent", "collapsed"])
        let proof = app.descendants(matching: .any)["proofLine"].firstMatch
        XCTAssertTrue(proof.waitForExistence(timeout: 5))
        sleep(1)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(verdict.isHittable)
        XCTAssertLessThanOrEqual(proof.frame.maxY, window.maxY - 20, "proof line must not be clipped by the sheet edge")
        XCTAssertFalse(app.descendants(matching: .any)["carousel"].firstMatch.isHittable)
        XCTAssertFalse(app.buttons["branch-0"].isHittable)
        shot("s7-collapsed-header-only")
    }

    /// Asking about a real rulebook without any credential (`-noKey` ignores a bundled token too) opens
    /// Settings, with the developer options open; never the scripted demo.
    func testRealRulebookWithoutCredentialOpensSettings() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-the-sample.pdf")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { ctx in
            ctx.beginPage()
            ("Some other game. Players take turns." as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        try pdf.write(to: url)
        continueAfterFailure = false
        app.launchArguments = ["-pdfPath", url.path, "-noKey", "YES", "-ask", "Can I pass?"]
        app.launch()
        let active = app.staticTexts["activeRoute"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertEqual(active.label, "No answer service set up")
        XCTAssertTrue(app.descendants(matching: .any)["apiKeyField"].firstMatch.exists)
        XCTAssertFalse(verdict.exists)
        XCTAssertFalse(app.descendants(matching: .any)["demoNote"].firstMatch.exists)
    }

    // MARK: Regressions found by hand on 2026-11-21 (owner, Azul): answer polish

    /// Step card text must never render outside its card (4-*.png), at default and AX text sizes;
    /// all cards share one height and long text offers "More", which opens that step expanded.
    func testCardTextStaysInsideCard() throws {
        let path = try demoAnswer(verdict: "Keep 2, discard 1.", steps: [
            ("Short", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Long", Self.longText, 4, "keeps up to 2 unused energy instead of discarding them"),
            ("Medium", "Anything above 2 is still discarded, so 1 of your 3 energy goes back to the supply.", 3, Self.goodQuote),
        ])
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL"] {
            launch(["-present", "YES", "-demoAnswer", path, "-UIPreferredContentSizeCategoryName", size])
            XCTAssertTrue(app.scrollViews["carousel"].waitForExistence(timeout: 5))
            sleep(1)
            let cards = app.descendants(matching: .any).matching(identifier: "stepCard").allElementsBoundByIndex
            XCTAssertEqual(cards.count, 3, size)
            let heights = Set(cards.map { Int($0.frame.height.rounded()) })
            XCTAssertEqual(heights.count, 1, "all cards share one height (\(size)): \(heights)")
            for card in cards {
                for text in card.descendants(matching: .staticText).matching(identifier: "stepCardText").allElementsBoundByIndex {
                    XCTAssertTrue(card.frame.insetBy(dx: -1, dy: -1).contains(text.frame),
                                  "text \(text.frame) outside card \(card.frame) at \(size)")
                }
            }
            shot("cards-equal-height-\(size)")
            app.terminate()
        }
        launch(["-present", "YES", "-demoAnswer", path, "-card", "1"])
        let more = app.buttons["cardMore"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.buttons["stepRow-1"].waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertTrue(app.buttons["stepRow-1"].isHittable, "More opens the expanded answer at that step")
        shot("card-more-expanded")
    }

    /// A long verdict is capped at three lines on the sheet (owner: "5 bold lines"); expanded shows it all.
    func testLongVerdictIsCappedUntilExpanded() throws {
        let long = "You still must pick tiles, and any you can't or don't want to place go to your floor line, costing you minus points. Taking is not optional, and the starting player marker counts as a floor tile too."
        let path = try demoAnswer(verdict: long, steps: [("Rule", "Unused energy is discarded.", 3, Self.goodQuote)])
        launch(["-present", "YES", "-demoAnswer", path])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        sleep(1)
        let capped = verdict.frame.height
        XCTAssertEqual(verdict.label, long, "VoiceOver still gets the whole verdict")
        app.terminate()
        launch(["-present", "YES", "-demoAnswer", path, "-detent", "expanded"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertGreaterThan(verdict.frame.height, capped * 1.3, "expanded shows the whole verdict")
        // Three title3 lines are well under 4.2 × the proof line's height.
        let proof = app.descendants(matching: .any)["proofLine"].firstMatch
        XCTAssertLessThan(capped, proof.frame.height * 4.2)
    }

    /// The cited passage is spotlit (2-/3-*.png: highlight invisible); a quote that doesn't match
    /// says so on the PDF instead of silently showing the page.
    func testSpotlightAndExplicitMiss() throws {
        let path = try demoAnswer(verdict: "Discard it.", steps: [
            ("Rule", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Missing", "This quote is not in the book.", 3, Self.missingQuote),
        ])
        launch(["-present", "YES", "-demoAnswer", path])
        let pdf = app.descendants(matching: .any)["pdfView"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "spotlight"), object: pdf)], timeout: 3) == .completed,
                      "\(pdf.value ?? "nil")")
        XCTAssertFalse(app.descendants(matching: .any)["highlightNote"].firstMatch.exists)
        shot("spotlight-step1")
        app.terminate()
        launch(["-present", "YES", "-demoAnswer", path, "-card", "1"])
        let note = app.descendants(matching: .any)["highlightNote"].firstMatch
        // Wait on the label itself: the note can exist a moment before its text settles.
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "not found"), object: note)], timeout: 5), .completed, note.label)
        XCTAssertFalse((pdf.value as? String ?? "").contains("spotlight"), "\(pdf.value ?? "nil")")
        shot("spotlight-miss-note")
    }

    /// Half of this quote is on p.3 ("at the end of your turn you must discard all unused energy"),
    /// the rest is invented: Core finds the long fragment and the app spotlights that part.
    private static let partialQuote = "At the end of your turn you must discard all unused energy, and players may then trade it freely with each other."

    /// One step citing two passages: a partial match, then an exact one.
    private func twoQuoteAnswer() throws -> String {
        let json: [String: Any] = [
            "restated_question": "What happens to unused energy?", "verdict": "Discard it.", "confidence": "stated",
            "steps": [["title": "Rule", "text": "Unused energy is discarded.",
                       "evidence": [["page": 3, "quote": Self.partialQuote, "box": NSNull()],
                                    ["page": 3, "quote": Self.goodQuote, "box": NSNull()]]]],
            "branches": [], "assumptions": [], "needs_web": false,
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url.path
    }

    /// A partially found quote is spotlit with "Part of the passage highlighted" (not the whole
    /// page); the pager says what it pages through ("Quote 1 of 2 ›") and never overlaps the note,
    /// at default and accessibility text sizes.
    func testPartialMatchNoteAndQuotePager() throws {
        let path = try twoQuoteAnswer()
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL"] {
            launch(["-present", "YES", "-demoAnswer", path, "-UIPreferredContentSizeCategoryName", size])
            let pdf = app.descendants(matching: .any)["pdfView"].firstMatch
            let note = app.descendants(matching: .any)["highlightNote"].firstMatch
            let pager = app.buttons["evidencePager"]
            XCTAssertTrue(note.waitForExistence(timeout: 5))
            XCTAssertTrue(note.label.contains("Part of the passage highlighted"), note.label)
            XCTAssertTrue((pdf.value as? String ?? "").contains("spotlight"), "partial match is spotlit: \(pdf.value ?? "nil")")
            XCTAssertTrue(pager.exists)
            XCTAssertEqual(pager.label, "Quote 1 of 2")
            XCTAssertFalse(note.frame.intersects(pager.frame), "note \(note.frame) overlaps pager \(pager.frame) at \(size)")
            XCTAssertGreaterThanOrEqual(note.frame.minX, 0)
            XCTAssertLessThanOrEqual(note.frame.maxX, app.windows.firstMatch.frame.maxX)
            shot("partial-note-\(size)")
            pager.tap()
            XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Quote 2 of 2"), object: pager)], timeout: 3) == .completed, pager.label)
            XCTAssertFalse(note.exists, "an exact match needs no note")
            app.terminate()
        }
        // Answer Details names the partial match and its coverage.
        launch(["-present", "YES", "-demoAnswer", path])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].firstMatch.tap()
        app.buttons["Answer Details"].tap()
        let partial = app.descendants(matching: .any)["evidence-1.1"].firstMatch
        XCTAssertTrue(partial.waitForExistence(timeout: 3))
        XCTAssertTrue(partial.label.hasPrefix("Partly matched"), partial.label)
        XCTAssertEqual(app.staticTexts["detailsSummary"].label, "2 of 2 passages highlighted")
        shot("answer-details-partial")
    }

    /// ⋯ → Answer Details lists every cited passage with its match status, and copies the JSON.
    func testAnswerDetailsListsMatchStatus() throws {
        let path = try demoAnswer(verdict: "Discard it.", steps: [
            ("Rule", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Missing", "This quote is not in the book.", 3, Self.missingQuote),
        ])
        launch(["-present", "YES", "-demoAnswer", path])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].firstMatch.tap()
        app.buttons["Answer Details"].tap()
        let first = app.descendants(matching: .any)["evidence-1.1"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        XCTAssertTrue(first.label.hasPrefix("Matched"), first.label)
        let second = app.descendants(matching: .any)["evidence-2.1"].firstMatch
        XCTAssertTrue(second.label.hasPrefix("Not matched"), second.label)
        XCTAssertEqual(app.staticTexts["detailsSummary"].label, "1 of 2 passages highlighted")
        shot("answer-details")
        app.buttons["copyAnswerJSON"].tap()
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout: 2))
    }

    /// Landscape (1-landscape-same-color.png): the navigation bar must be clearly darker than the
    /// answer column next to it.
    func testNavigationBarIsDarkerThanAnswerColumn() throws {
        launch(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        XCTAssertTrue(verdict.isHittable)
        let bar = app.navigationBars.firstMatch.frame
        let column = verdict.frame
        let shot = XCUIScreen.main.screenshot().image
        let window = app.windows.firstMatch.frame
        let barLuma = try XCTUnwrap(luma(shot, at: CGPoint(x: column.minX + 2, y: bar.maxY - 6), window: window))
        let panelLuma = try XCTUnwrap(luma(shot, at: CGPoint(x: column.minX - 4, y: column.maxY + 30), window: window))
        XCTAssertLessThan(barLuma, panelLuma - 0.04, "bar \(barLuma) vs panel \(panelLuma)")
        self.shot("landscape-bar-darker")
    }

    // MARK: Regressions found by hand on 2026-11-22 (owner, iPhone 18 Pro): sheet breathing, jumps

    /// While an answer streams, the sheet must stay put: content fills in place. Before the fix the
    /// detents were re-measured from the content on every streamed event, so the sheet shrank under
    /// the verdict and grew back each time (the "panel hides and reappears" bug).
    func testSheetStaysPutWhileAnswerStreams() {
        // A slower stream (3×) so the sheet can be sampled many times between events.
        launch(["-ask", "what happens to my energy at end of turn if I have the battery", "-demoPace", "3"])
        let sheet = app.descendants(matching: .any)["answerSheet"].firstMatch
        let close = app.buttons["closeAnswer"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let appeared = Date()
        var streaming: [(t: TimeInterval, exists: Bool, top: CGFloat)] = []
        var after: [(exists: Bool, top: CGFloat)] = []
        var doneAt: Date?
        while Date().timeIntervalSince(appeared) < 40 {
            let t = Date().timeIntervalSince(appeared)
            let exists = sheet.exists
            let top = exists ? sheet.frame.minY : .infinity
            // Completion swaps Stop for Close in the same update that may grow the sheet, so a
            // sample only counts as "while streaming" if Close still isn't there after taking it.
            if doneAt == nil, close.exists { doneAt = Date() }
            if let d = doneAt {
                after.append((exists, top))
                if Date().timeIntervalSince(d) > 1.5 { break }
            } else {
                streaming.append((t, exists, top))
            }
        }
        XCTAssertNotNil(doneAt, "the demo answer completes")
        // Skip the presentation animation (the sheet rises once), then it must not move.
        let settled = streaming.filter { $0.t > 1.5 }
        XCTAssertGreaterThan(settled.count, 5, "enough samples while streaming")
        XCTAssertTrue(settled.allSatisfy(\.exists), "the sheet never disappears while streaming")
        let tops = settled.map(\.top)
        let ref = tops.first ?? 0
        XCTAssertTrue(tops.allSatisfy { abs($0 - ref) <= 1 }, "sheet top moved while streaming: \(tops.map { Int($0) })")
        // Once complete it may grow once to fit late content (branches), but never shrinks or hides.
        XCTAssertTrue(after.allSatisfy { $0.exists && $0.top <= ref + 1 }, "after completion: \(after.map { Int($0.top) })")
        shot("streamed-medium")
    }

    /// The sheet's content sits inside standard margins: the verdict and the close button clear the
    /// grabber and the rounded corners, and cards / rows keep off the sheet's sides, at every detent.
    func testSheetContentHasStandardMargins() {
        // The floating sheet at the lower detents can be drawn very slightly scaled down, so
        // margins are checked at 95 % of their design value.
        let edge: CGFloat = 20 * 0.95, top: CGFloat = 24 * 0.95
        for detent in ["collapsed", "medium", "expanded"] {
            launch(["-present", "YES", "-detent", detent])
            XCTAssertTrue(verdict.waitForExistence(timeout: 5))
            sleep(1)
            let sheet = app.descendants(matching: .any)["answerSheet"].firstMatch.frame
            let close = app.buttons["closeAnswer"].frame
            XCTAssertGreaterThanOrEqual(verdict.frame.minY - sheet.minY, top, "verdict clears the grabber (\(detent))")
            XCTAssertGreaterThanOrEqual(close.minY - sheet.minY, edge, "close button clears the top edge (\(detent))")
            XCTAssertGreaterThanOrEqual(sheet.maxX - close.maxX, edge, "close button clears the corner (\(detent))")
            XCTAssertGreaterThanOrEqual(verdict.frame.minX - sheet.minX, edge, "verdict margin (\(detent))")
            if detent != "collapsed" {
                let card = app.descendants(matching: .any).matching(identifier: "stepCard").firstMatch.frame
                XCTAssertGreaterThanOrEqual(card.minX - sheet.minX, edge, "card margin (\(detent))")
                if detent == "medium" {
                    let field = app.descendants(matching: .any)["followUpField"].firstMatch
                    let thumbsDown = app.buttons["thumbsDown"].firstMatch
                    XCTAssertTrue(field.exists && thumbsDown.exists)
                    XCTAssertGreaterThanOrEqual(field.frame.minX - sheet.minX, edge, "follow-up field margin")
                    XCTAssertGreaterThanOrEqual(sheet.maxX - thumbsDown.frame.maxX, edge, "thumbs margin")
                }
            }
            shot("margins-\(detent)")
            app.terminate()
        }
    }

    /// Relative luminance (0–1) of the pixel at a window point. Screen captures stay in portrait
    /// pixel order in landscape-left: window (x, y) is image (width − y, x).
    private func luma(_ image: UIImage, at p: CGPoint, window: CGRect) -> CGFloat? {
        guard let cg = image.cgImage else { return nil }
        let portraitImage = cg.width < cg.height
        let landscapeWindow = window.width > window.height
        let q = portraitImage && landscapeWindow ? CGPoint(x: window.height - p.y, y: p.x) : p
        let scale = CGFloat(cg.width) / (portraitImage && landscapeWindow ? window.height : window.width)
        let x = Int(q.x * scale), y = Int(q.y * scale)
        guard x >= 0, y >= 0, x < cg.width, y < cg.height,
              let cropped = cg.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * CGFloat(px[0]) + 0.7152 * CGFloat(px[1]) + 0.0722 * CGFloat(px[2])) / 255
    }
}
