import XCTest

/// S1 · My Games: the app opens on the list of imported rulebooks. Every test starts from an
/// empty library (`-emptyLibrary YES`) on the sample rulebook, with demo answers.
/// Set SCREENSHOT_DIR in the test environment to save PNGs.
@MainActor
final class LibraryUITests: XCTestCase {
    private let app = XCUIApplication()
    private static let sampleRow = "game-power-plant-rush.pdf"

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) {
        app.launchArguments = ["-demo", "YES"] + args
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

    private var listBar: XCUIElement { app.navigationBars["My Games"] }
    private var sampleRow: XCUIElement { app.buttons[Self.sampleRow] }
    private var pdf: XCUIElement { app.descendants(matching: .any)["pdfView"].firstMatch }

    private func backToList() {
        app.navigationBars.buttons["My Games"].firstMatch.tap()
        XCTAssertTrue(app.buttons["addRulebook"].waitForExistence(timeout: 3))
    }

    func testEmptyState() {
        launch(["-emptyLibrary", "YES"])
        XCTAssertTrue(listBar.waitForExistence(timeout: 5), "the app opens on My Games")
        XCTAssertTrue(app.staticTexts["No Games Yet"].exists)
        XCTAssertTrue(app.buttons["emptyAddRulebook"].exists)
        XCTAssertTrue(app.buttons["trySample"].exists)
        XCTAssertTrue(app.buttons["addRulebook"].exists, "Add a Rulebook is also in the toolbar")
        XCTAssertTrue(app.buttons["settings"].exists, "Settings moved to the list's toolbar")
        shot("01-empty")
        app.buttons["settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testTrySampleAddsAndOpensIt() {
        launch(["-emptyLibrary", "YES"])
        XCTAssertTrue(app.buttons["trySample"].waitForExistence(timeout: 5))
        app.buttons["trySample"].tap()
        // Opens the new game right away…
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Power plant rush"].exists)
        shot("03-viewer-from-list")
        // …and it is in the list behind it.
        backToList()
        XCTAssertTrue(sampleRow.waitForExistence(timeout: 3))
        XCTAssertTrue(sampleRow.label.contains("Power plant rush"))
        XCTAssertTrue(sampleRow.label.contains("Opened"), "row shows when it was last used: \(sampleRow.label)")
        XCTAssertFalse(app.staticTexts["No Games Yet"].exists)
    }

    func testOpenGameAndGoBack() {
        launch(["-emptyLibrary", "YES", "-seedSample", "YES"])
        XCTAssertTrue(sampleRow.waitForExistence(timeout: 5))
        sleep(1)  // let the cover render
        shot("02-list")
        sampleRow.tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        // Ask, go back, come back: the same game resumes with its answer.
        let field = app.textFields["askField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("what happens to my energy at end of turn if I have the battery\n")
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 15))
        app.buttons["closeAnswer"].tap()
        backToList()
        XCTAssertFalse(pdf.exists)
        sampleRow.tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 2), "the answer is still there")
        XCTAssertFalse(app.buttons["Settings"].exists, "Settings lives on My Games, not the viewer's ⋯")
    }

    func testSwipeToDelete() {
        launch(["-emptyLibrary", "YES", "-seedSample", "YES"])
        XCTAssertTrue(sampleRow.waitForExistence(timeout: 5))
        sampleRow.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        shot("04-swipe-delete")
        delete.tap()
        XCTAssertTrue(sampleRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Games Yet"].waitForExistence(timeout: 2))
        // Deleted for good: still gone after a relaunch.
        app.terminate()
        launch([])
        XCTAssertTrue(app.staticTexts["No Games Yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(sampleRow.exists)
    }

    func testRelaunchOpensOnListWithGame() {
        launch(["-emptyLibrary", "YES"])
        XCTAssertTrue(app.buttons["trySample"].waitForExistence(timeout: 5))
        app.buttons["trySample"].tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        // Relaunch while the viewer is open: the app opens on the list, not the last rulebook.
        app.terminate()
        launch([])
        XCTAssertTrue(listBar.waitForExistence(timeout: 5))
        XCTAssertTrue(sampleRow.waitForExistence(timeout: 3))
        XCTAssertFalse(pdf.exists)
    }

    func testLaunchArgumentDocumentPushesOverListWithoutJoiningIt() {
        launch(["-emptyLibrary", "YES", "-sample", "YES"])
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        backToList()
        XCTAssertTrue(app.staticTexts["No Games Yet"].exists, "-sample is not added to My Games")
    }
}
