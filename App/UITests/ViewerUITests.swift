import XCTest

/// The viewer screen on the sample rulebook with demo answers: the PDF (whole page, evidence zoom, pan to
/// inspect, double-tap, spotlight and notes, the quote pager), the ⋯ menu and Answer Details, rotation to
/// the answer column, and Settings when no credential is set up.
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

    /// Close → the ask field; ⋯ → Show Answer; phone landscape moves the answer to the column.
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

    /// A rulebook opens with the whole page visible, not zoomed to page width.
    func testRulebookOpensOnWholePage() {
        launch([])
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertEqual(pdf.value as? String, "Whole page")
        // Once an answer focuses evidence it zooms; closing the answer goes back to the whole page.
        app.terminate()
        launch(["-present", "YES"])
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue((pdf.value as? String ?? "").hasPrefix("Zoomed"))
        app.buttons["closeAnswer"].tap()
        XCTAssertTrue(wait(pdf, "value == %@", "Whole page"))
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
        app.launchArguments = ["-pdfPath", url.path, "-noKey", "YES", "-ask", "Can I pass?"]
        app.launch()
        let active = app.staticTexts["activeRoute"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertEqual(active.label, "No answer service set up")
        XCTAssertTrue(app.descendants(matching: .any)["apiKeyField"].firstMatch.exists)
        XCTAssertFalse(verdict.exists)
        XCTAssertFalse(app.descendants(matching: .any)["demoNote"].firstMatch.exists)
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

    /// A partially found quote is spotlit with "Part of the passage highlighted" (not the whole
    /// page); the pager says what it pages through ("Quote 1 of 2 ›") and never overlaps the note,
    /// at default and accessibility text sizes.
    func testPartialMatchNoteAndQuotePager() throws {
        let path = try twoQuoteAnswer()
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL"] {
            launch(["-present", "YES", "-demoAnswer", path, "-UIPreferredContentSizeCategoryName", size])
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

    /// Half of this quote is on p.3 ("at the end of your turn you must discard all unused energy"),
    /// the rest is invented: Core finds the long fragment and the app spotlights that part.
    private static let partialQuote = "At the end of your turn you must discard all unused energy, and players may then trade it freely with each other."

    /// One step citing two passages: a partial match, then an exact one.
    private func twoQuoteAnswer() throws -> String {
        try demoAnswer(verdict: "Discard it.", steps: [("Rule", "Unused energy is discarded.", [(3, Self.partialQuote), (3, Self.goodQuote)])])
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
