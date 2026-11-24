import XCTest

/// S1 · My Games: navigation from the list into a game and back, on the running app. Adding, deleting
/// and what a relaunch shows are unit-tested (`LibraryModelTests`), the empty state and the list's looks
/// in-process (`ViewerLayoutTests`, `ScreenSnapshotTests`).
final class LibraryUITests: UITestCase {
    private static let sampleRow = "game-power-plant-rush.pdf"

    private func launch(_ args: [String]) {
        app.launchArguments = ["-demo", "YES", "-demoPace", "0"] + args
        app.launch()
    }

    private var listBar: XCUIElement { app.navigationBars["My Games"] }
    private var sampleRow: XCUIElement { app.buttons[Self.sampleRow] }

    private func backToList() {
        app.navigationBars.buttons["My Games"].firstMatch.tap()
        XCTAssertTrue(app.buttons["addRulebook"].waitForExistence(timeout: 3))
    }

    /// Empty list → Try the Sample opens the new game; ask, go back to the list (the game is in it),
    /// open it again: the same game resumes with its answer.
    func testTrySampleOpenGoBackAndResume() {
        launch(["-emptyLibrary", "YES"])
        XCTAssertTrue(listBar.waitForExistence(timeout: 5), "the app opens on My Games")
        XCTAssertTrue(app.buttons["trySample"].waitForExistence(timeout: 5))
        app.buttons["trySample"].tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Power plant rush"].exists)
        let field = app.textFields["askField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("what happens to my energy at end of turn if I have the battery\n")
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 8))
        app.buttons["closeAnswer"].tap()
        backToList()
        XCTAssertFalse(pdf.exists)
        XCTAssertTrue(sampleRow.waitForExistence(timeout: 3))
        XCTAssertTrue(sampleRow.label.contains("Opened"), "row shows when it was last used: \(sampleRow.label)")
        shot("02-list")
        sampleRow.tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 2), "the answer is still there")
        XCTAssertFalse(app.buttons["Settings"].exists, "Settings lives on My Games, not the viewer's ⋯")
    }
}
