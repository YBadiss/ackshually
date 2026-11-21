import XCTest

/// Drives the M2 interactions on the sample rulebook with demo answers (no API key).
/// Set SCREENSHOT_DIR in the test environment to save PNGs (used for docs/m2-screenshots).
@MainActor
final class ViewerUITests: XCTestCase {
    private let app = XCUIApplication()

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

    func testStreamingThenStepping() {
        launch(["-ask", "what happens to my energy at end of turn if I have the battery"])
        XCTAssertTrue(app.buttons["stop"].waitForExistence(timeout: 3))
        shot("s3-waiting")
        // S4: header arrives first, then the verdict and step 1.
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 8))
        shot("s4-streaming")
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        sleep(3)
        shot("s5-step1")
        carousel.swipeLeft()
        sleep(1)
        shot("s6-step2")
        // Tap the right peek → next card.
        let peek = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
        peek.tap()
        sleep(1)
        shot("s6-step3")
        XCTAssertTrue(app.staticTexts["3 · Step"].exists || app.staticTexts["4 · Result"].exists)
    }

    func testInspectBackToStepAndDoubleTap() {
        launch(["-present", "YES", "-card", "1"])
        let window = app.windows.firstMatch
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 5))
        sleep(1)
        // S8: pan the PDF → Back to step pill. (XCUITest press-and-drag reads as text selection; swipe pans.)
        XCTAssertFalse(app.buttons["backToStep"].exists)
        window.swipeDown(velocity: .slow)
        XCTAssertTrue(app.buttons["backToStep"].waitForExistence(timeout: 2))
        shot("s8-inspect")
        app.buttons["backToStep"].tap()
        sleep(1)
        XCTAssertFalse(app.buttons["backToStep"].exists)
        // Tapping the PDF never changes steps.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["2 · Step"].exists)
        // Double-tap: evidence ↔ full page.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).doubleTap()
        sleep(1)
        shot("s8-full-page")
    }

    func testBranchAndDetents() {
        launch(["-present", "YES"])
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 5))
        app.buttons["No Battery? Discard all 3. ›"].tap()
        XCTAssertTrue(app.buttons["‹ Main answer"].waitForExistence(timeout: 2))
        shot("s9-branch")
        app.buttons["‹ Main answer"].tap()
        // Drag the sheet down (S7) and back up, then up again (S9).
        let grab = app.descendants(matching: .any).matching(identifier: "sheetGrabber").firstMatch
        grab.swipeDown()
        sleep(1)
        shot("s7-collapsed")
        grab.swipeUp()
        sleep(1)
        grab.swipeUp()
        sleep(1)
        shot("s9-expanded")
    }

    func testFollowUpKeepsContext() {
        launch(["-present", "YES"])
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        for _ in 0..<3 { carousel.swipeLeft(); usleep(400_000) }
        let field = app.textFields["followUpField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        shot("s6-last-card")
        field.tap()
        field.typeText("And with two Batteries?\n")
        XCTAssertTrue(app.buttons["stop"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 10))
    }
}
