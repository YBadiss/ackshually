import XCTest

/// The answer sheet on screen (S4–S9): detents and dragging, card gestures, layout and margins, the
/// streaming sheet holding still. Answer logic (streaming states, stop, branches, More, follow-ups) is
/// unit-tested in `AckshuallyTests`; these tests check what only the real screen shows.
final class AnswerSheetUITests: UITestCase {
    private static let longText = Array(repeating: "A player who owns a Battery keeps up to 2 unused energy at the end of the turn instead of discarding them, and any additional energy is discarded as normal.", count: 3).joined(separator: " ")

    /// S5/S6: swipe between cards; a tap on the right peek goes to the next card.
    func testSwipeAndPeekTapStepCards() {
        launchSample(["-present", "YES"])
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCard("Card 1 of 3"))
        shot("s5-step1")
        carousel.swipeLeft()
        // A simulator swipe right after the sheet settles occasionally doesn't register: retry once.
        if !waitForCard("Card 2 of 3") { carousel.swipeLeft() }
        XCTAssertTrue(waitForCard("Card 2 of 3"))
        shot("s6-step2")
        carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertTrue(waitForCard("Card 3 of 3"))
    }

    /// S7/S9: a branch row and Main Answer are tappable rows; the system sheet drags between all three
    /// detents; a step row in the expanded answer jumps back to its card at medium.
    /// Hardened (it flaked once): every drag waits for the detent's content instead of sleeping, and
    /// retries once if the simulator dropped the drag.
    func testBranchAndDetents() {
        launchSample(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
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

    /// The follow-up field and thumbs sit in their own row under the shelf, and a typed follow-up is sent.
    func testFollowUpRowSitsUnderTheShelf() {
        launchSample(["-present", "YES"])
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        let field = app.textFields["followUpField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(identifier: "thumbsUp").allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertGreaterThan(field.frame.minY, carousel.frame.maxY)
        shot("s6-follow-up-row")
        field.tap()
        // On a loaded simulator the keyboard can take a moment to take focus; typing earlier fails
        // with "Neither element nor any descendant has keyboard focus".
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("And with two Batteries?\n")
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 8), "the follow-up is answered")
    }

    /// Collapsed sheet (S7): verdict and proof line fully on screen, nothing cut off below them.
    func testCollapsedShowsWholeHeaderOnly() {
        launchSample(["-present", "YES", "-detent", "collapsed"])
        let proof = any("proofLine")
        XCTAssertTrue(proof.waitForExistence(timeout: 5))
        XCTAssertTrue(waitHittable(verdict))
        sleep(1)  // the sheet's presentation spring settles (frames are read once)
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(proof.frame.maxY, window.maxY - 20, "proof line must not be clipped by the sheet edge")
        XCTAssertFalse(any("carousel").isHittable)
        XCTAssertFalse(app.buttons["branch-0"].isHittable)
        shot("s7-collapsed-header-only")
    }

    /// Step card text never renders outside its card (owner's Azul test), at default and AX text sizes;
    /// all cards share one height and long text offers "More", which opens that step expanded.
    func testCardTextStaysInsideCard() throws {
        let path = try demoAnswer(verdict: "Keep 2, discard 1.", steps: [
            ("Short", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Long", Self.longText, 4, "keeps up to 2 unused energy instead of discarding them"),
            ("Medium", "Anything above 2 is still discarded, so 1 of your 3 energy goes back to the supply.", 3, Self.goodQuote),
        ])
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL"] {
            launchSample(["-present", "YES", "-demoAnswer", path, "-UIPreferredContentSizeCategoryName", size])
            XCTAssertTrue(app.scrollViews["carousel"].waitForExistence(timeout: 5))
            let cardQuery = app.descendants(matching: .any).matching(identifier: "stepCard")
            XCTAssertTrue(wait(cardQuery.element(boundBy: 2), "exists == true"), size)
            let cards = cardQuery.allElementsBoundByIndex
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
        launchSample(["-present", "YES", "-demoAnswer", path, "-card", "1"])
        let more = app.buttons["cardMore"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(waitHittable(app.buttons["stepRow-1"]), "More opens the expanded answer at that step")
        shot("card-more-expanded")
    }

    /// A long verdict is capped at three lines on the sheet (owner: "5 bold lines"); expanded shows it all.
    func testLongVerdictIsCappedUntilExpanded() throws {
        let long = "You still must pick tiles, and any you can't or don't want to place go to your floor line, costing you minus points. Taking is not optional, and the starting player marker counts as a floor tile too."
        let path = try demoAnswer(verdict: long, steps: [("Rule", "Unused energy is discarded.", 3, Self.goodQuote)])
        launchSample(["-present", "YES", "-demoAnswer", path])
        XCTAssertTrue(waitHittable(verdict, timeout: 5))
        let capped = verdict.frame.height
        XCTAssertEqual(verdict.label, long, "VoiceOver still gets the whole verdict")
        let proof = any("proofLine")
        // Three title3 lines are well under 4.2 × the proof line's height.
        XCTAssertLessThan(capped, proof.frame.height * 4.2)
        app.terminate()
        launchSample(["-present", "YES", "-demoAnswer", path, "-detent", "expanded"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue(eventually(timeout: 5) { self.verdict.frame.height > capped * 1.3 }, "expanded shows the whole verdict")
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

    /// Once a streamed answer is complete the cards fit their content again (equal height across
    /// the shelf): the loading card's reserved height only holds while streaming.
    func testCardsFitContentAfterStreaming() throws {
        let path = try demoAnswer(verdict: "Discard it.", steps: [
            ("Rule", "Unused energy is discarded.", 3, Self.goodQuote),
            ("Battery", "A Battery keeps 2.", 4, "keeps up to 2 unused energy instead of discarding them"),
        ])
        launchSample(["-ask", "What happens to unused energy?", "-demoAnswer", path], pace: 1)
        let loading = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND label == %@", "stepCard", "Next step loading")).firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 8))
        let placeholder = loading.frame.height
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 12))
        sleep(1)  // the shelf animates to its new height
        let cards = app.descendants(matching: .any).matching(identifier: "stepCard").allElementsBoundByIndex
        XCTAssertEqual(cards.count, 2)
        let heights = cards.map { $0.frame.height }
        XCTAssertEqual(Set(heights.map { Int($0.rounded()) }).count, 1, "equal heights: \(heights)")
        XCTAssertLessThan(heights[0], placeholder * 0.75, "card \(heights[0]) fits its 1-line text, not the placeholder \(placeholder)")
        shot("cards-fit-after-streaming")
    }

    /// The sheet's content sits inside standard margins: the verdict and the close button clear the
    /// grabber and the rounded corners, and cards / rows keep off the sheet's sides, at every detent.
    func testSheetContentHasStandardMargins() {
        // The floating sheet at the lower detents can be drawn very slightly scaled down, so
        // margins are checked at 95 % of their design value.
        let edge: CGFloat = 20 * 0.95, top: CGFloat = 24 * 0.95
        for detent in ["collapsed", "medium", "expanded"] {
            launchSample(["-present", "YES", "-detent", detent])
            XCTAssertTrue(waitHittable(verdict, timeout: 5))
            sleep(1)  // the sheet's presentation spring settles (frames are read once)
            let sheet = any("answerSheet").frame
            let close = app.buttons["closeAnswer"].frame
            XCTAssertGreaterThanOrEqual(verdict.frame.minY - sheet.minY, top, "verdict clears the grabber (\(detent))")
            XCTAssertGreaterThanOrEqual(close.minY - sheet.minY, edge, "close button clears the top edge (\(detent))")
            XCTAssertGreaterThanOrEqual(sheet.maxX - close.maxX, edge, "close button clears the corner (\(detent))")
            XCTAssertGreaterThanOrEqual(verdict.frame.minX - sheet.minX, edge, "verdict margin (\(detent))")
            if detent != "collapsed" {
                let card = app.descendants(matching: .any).matching(identifier: "stepCard").firstMatch.frame
                XCTAssertGreaterThanOrEqual(card.minX - sheet.minX, edge, "card margin (\(detent))")
                if detent == "medium" {
                    let field = any("followUpField")
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
}
