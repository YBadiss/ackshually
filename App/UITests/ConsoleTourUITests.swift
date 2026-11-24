import XCTest

/// One pass over every screen for the console check (`App/TestPlans/console-check.sh` runs Smoke and fails on
/// any app log line that isn't known system noise), so this test only has to visit each screen and state once:
/// launch, My Games with a cover, a game with an add-on (S13: Playing with → Play joins both books), the book
/// switcher, back to My Games, the same game again with the add-on unticked (the open viewer swaps its PDF:
/// the owner's "Cycle detected" console, 2026-11-24), a demo question, Playing with from the viewer's title,
/// the sheet at each detent, typing in the follow-up field (keyboard up), back to My Games, Settings.
final class ConsoleTourUITests: UITestCase {
    private var row: XCUIElement { app.buttons["game-power-plant-rush.pdf"] }
    private var confirm: XCUIElement { app.buttons["playingWithConfirm"] }
    private var solar: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Solar Expansion")).firstMatch
    }

    private func backToMyGames() {
        app.navigationBars.buttons["My Games"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 3))
    }

    func testTourEveryScreen() {
        app.launchArguments = ["-emptyLibrary", "YES", "-seedSampleSet", "YES", "-demo", "YES", "-demoPace", "0"]
        app.launch()

        // My Games, with the game's cover.
        XCTAssertTrue(app.navigationBars["My Games"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("2 rulebooks"), row.label)

        // A game with an add-on asks what you play with first; Play joins both books.
        row.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Playing with opens before the game")
        confirm.tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["gameTitleButton"].waitForExistence(timeout: 3))
        app.buttons["bookSwitcher"].firstMatch.tap()
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        solar.tap()

        // Back, untick the add-on, Play: the open session gets the core book alone, and the viewer swaps its PDF.
        backToMyGames()
        row.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        solar.tap()
        XCTAssertTrue(wait(solar, "value == %@", "Not tonight"))
        confirm.tap()
        XCTAssertTrue(pdf.waitForExistence(timeout: 10))
        XCTAssertTrue(wait(app.buttons["gameTitleButton"], "label == %@", "Power plant rush"), "only the core book is in play")
        XCTAssertTrue(wait(app.buttons["bookSwitcher"], "exists == false", timeout: 5), "one book: no book switcher")

        // Ask (keyboard up), the answer sheet comes up at medium.
        let field = app.textFields["askField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("what happens to my energy at end of turn if I have the battery\n")
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForCard("Card 1 of 3"))

        // Playing with from the viewer's title (the sheet at medium stays): tick the add-on again, Done.
        app.buttons["gameTitleButton"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        solar.tap()
        confirm.tap()
        XCTAssertTrue(wait(confirm, "exists == false", timeout: 3))

        // Each detent: collapsed, expanded (type a follow-up there; the keyboard comes up over the sheet).
        func dragUntil(_ y: CGFloat, _ done: () -> Bool) {
            for _ in 0..<2 where !done() { drag(verdict, toY: y) }
        }
        let branch = app.buttons["branch-0"]
        dragUntil(0.98) { waitHittable(branch, false) }
        XCTAssertFalse(branch.isHittable, "collapsed")
        let followUp = app.textFields["followUpField"]
        dragUntil(0.05) { waitHittable(followUp) }
        XCTAssertTrue(followUp.isHittable, "the follow-up field shows when expanded")
        followUp.tap()
        followUp.typeText("and with two batteries")
        XCTAssertTrue(app.buttons["send"].waitForExistence(timeout: 2))

        // Close the answer, back to My Games, Settings.
        app.buttons["closeAnswer"].tap()
        backToMyGames()
        app.buttons["settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        app.navigationBars["Settings"].buttons.firstMatch.tap()
        XCTAssertTrue(wait(app.navigationBars["Settings"], "exists == false", timeout: 3))
        XCTAssertTrue(row.waitForExistence(timeout: 3))
    }
}
