import XCTest

/// The answer sheet on screen (S4–S9): what only the running system sheet shows, its gestures, detents
/// and the sheet holding still while an answer streams. Its layout (margins, what each detent shows,
/// cards, the verdict cap, branch rows) is checked in-process by `AnswerLayoutTests` and its looks by
/// `ScreenSnapshotTests`; answer logic by the model unit tests.
final class AnswerSheetUITests: UITestCase {
    /// S5–S9 gestures on the system sheet: swipe between cards and tap the right peek for the next one;
    /// a branch row and Main Answer are tappable rows; the sheet drags between all three detents; a step
    /// row in the expanded answer jumps back to its card at medium.
    /// Hardened (it flaked once): every drag waits for the detent's content instead of sleeping, and
    /// retries once if the simulator dropped the drag.
    func testSwipeBranchAndDetents() {
        launchSample(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCard("Card 1 of 3"))
        carousel.swipeLeft()
        // A simulator swipe right after the sheet settles occasionally doesn't register: retry once.
        if !waitForCard("Card 2 of 3") { carousel.swipeLeft() }
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        shot("s6-step2")
        carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertTrue(waitForCard("Card 3 of 3"))
        let branch = app.buttons["branch-0"]
        XCTAssertTrue(waitHittable(branch))
        branch.tap()
        XCTAssertTrue(app.buttons["mainAnswer"].waitForExistence(timeout: 2))
        XCTAssertTrue(waitForCard("Card 1 of 1"))
        shot("s9-branch")
        app.buttons["mainAnswer"].tap()
        XCTAssertTrue(waitForCard("Card 1 of 3"))

        func dragUntil(_ y: CGFloat, _ done: () -> Bool) {
            for _ in 0..<2 where !done() { drag(verdict, toY: y) }
        }
        // Collapsed: the cards and branches go off screen, the verdict stays.
        dragUntil(0.98) { waitHittable(branch, false) }
        XCTAssertFalse(branch.isHittable)
        XCTAssertTrue(verdict.isHittable)
        shot("s7-collapsed")
        // Medium, then large (all steps).
        dragUntil(0.55) { waitHittable(branch) }
        XCTAssertTrue(branch.isHittable)
        let lastRow = app.buttons["stepRow-2"]
        dragUntil(0.05) { waitHittable(lastRow) }
        XCTAssertTrue(lastRow.isHittable)
        shot("s9-expanded")
        app.buttons["stepRow-1"].tap()
        XCTAssertTrue(waitForCard("Card 2 of 3"))
    }

    /// While an answer streams, the sheet stays put: content fills in place. Before the fix the detents
    /// were re-measured on every streamed event, so the sheet shrank under the verdict and grew back each
    /// time (the "panel hides and reappears" bug). This is the one UI test that watches a stream.
    func testSheetStaysPutWhileAnswerStreams() {
        // A slower stream (3×) so the sheet can be sampled many times between events.
        launchSample(["-ask", "what happens to my energy at end of turn if I have the battery"], pace: 3)
        let sheet = any("answerSheet")
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
        // Once complete it settles once to the finished content (branch rows in, the loading card's
        // reserved height out): one move in one direction, never hidden, no dip and bounce back.
        let path = [ref] + after.map(\.top)
        XCTAssertTrue(after.allSatisfy(\.exists), "the sheet never disappears after completion")
        let steps = zip(path, path.dropFirst()).map { $1 - $0 }.filter { abs($0) > 1 }
        XCTAssertTrue(steps.allSatisfy { $0 > 0 } || steps.allSatisfy { $0 < 0 },
                      "after completion the sheet moves once, one way: \(path.map { Int($0) })")
        shot("streamed-medium")
    }
}
