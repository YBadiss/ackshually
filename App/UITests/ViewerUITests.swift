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
        XCTAssertTrue(waitForCard("Card 1 of 4"))
        carousel.swipeLeft()
        // A simulator swipe right after the stream settles occasionally doesn't register: retry once.
        if !waitForCard("Card 2 of 4") { carousel.swipeLeft() }
        XCTAssertTrue(waitForCard("Card 2 of 4"))
        shot("s6-step2")
        // Tap the right peek → next card.
        carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertTrue(waitForCard("Card 3 of 4"))
        shot("s6-step3")
    }

    func testInspectBackToStepAndDoubleTap() {
        launch(["-present", "YES", "-card", "1"])
        let window = app.windows.firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCard("Card 2 of 4"))
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
        XCTAssertTrue(waitForCard("Card 2 of 4"))
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
        XCTAssertTrue(waitForCard("Card 1 of 2"))
        XCTAssertEqual(verdict.label, "Discard all 3.")
        shot("s9-branch")
        app.buttons["mainAnswer"].tap()
        XCTAssertTrue(waitForCard("Card 1 of 4"))
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
        XCTAssertTrue(waitForCard("Card 2 of 4"))
    }

    func testFollowUpKeepsContext() {
        launch(["-present", "YES"])
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        for _ in 0..<3 { carousel.swipeLeft(); usleep(400_000) }
        XCTAssertTrue(waitForCard("Card 4 of 4"))
        let field = app.textFields["followUpField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
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
        XCTAssertEqual(pdf.value as? String, "Zoomed")
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

    /// Asking about a real rulebook without an API key opens Settings; never the scripted demo.
    func testRealRulebookWithoutKeyAsksForKey() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-the-sample.pdf")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { ctx in
            ctx.beginPage()
            ("Some other game. Players take turns." as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        try pdf.write(to: url)
        continueAfterFailure = false
        app.launchArguments = ["-pdfPath", url.path, "-noKey", "YES", "-ask", "Can I pass?"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["apiKeyField"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(verdict.exists)
        XCTAssertFalse(app.descendants(matching: .any)["demoNote"].firstMatch.exists)
    }
}
