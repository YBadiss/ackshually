import XCTest

/// The viewer on the sample rulebook with demo answers: what only the running PDF view shows (panning
/// under the sheet, double-tap zoom, the spotlight and the "not found" note). Landscape, the zoom state,
/// the navigation bar, the note and pager layout, Answer Details and Settings are checked in-process
/// (`ViewerLayoutTests`, `ScreenSnapshotTests`); the logic by `ViewerModelTests`.
final class ViewerUITests: UITestCase {
    private func launch(_ args: [String]) { launchSample(args) }

    /// S8: the PDF stays pannable under the sheet; tapping the PDF never changes steps; double-tap
    /// goes back to the evidence after a pan, then toggles evidence zoom and the whole page.
    func testInspectAndDoubleTap() {
        launch(["-present", "YES", "-card", "1"])
        let window = app.windows.firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        sleep(1)
        // S8: the PDF stays pannable under the sheet (background interaction).
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        from.press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        shot("s8-inspect")
        // Double-tap after a pan: back to the evidence; the sheet and the card stay put.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).doubleTap()
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        XCTAssertFalse(app.buttons["backToStep"].exists, "no floating Back to Step button any more")
        // Tapping the PDF never changes steps.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        // Double-tap: evidence ↔ full page.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).doubleTap()
        sleep(1)
        shot("s8-full-page")
    }

    /// The cited passage is spotlit (2-/3-*.png: highlight invisible); a quote that doesn't match
    /// says so on the PDF instead of silently showing the page.
    func testSpotlightAndExplicitMiss() throws {
        let path = try demoAnswer(verdict: "Discard it.", steps: [
            ("Rule", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Missing", "This quote is not in the book.", 3, Self.missingQuote),
        ])
        launch(["-present", "YES", "-demoAnswer", path])
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
}
