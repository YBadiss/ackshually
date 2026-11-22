import XCTest

/// The answer route through the ackshually server, against a local stub (`StubServer`) with fake tokens
/// injected by Debug-only launch arguments. Never the real server, never a real token.
@MainActor
final class ServerRouteUITests: XCTestCase {
    private let app = XCUIApplication()
    private var stub: StubServer!
    private var pdfPath = ""

    private static let answer: [String: Any] = [
        "restated_question": "Can I pass on my turn?", "verdict": "Yes, you may pass.", "confidence": "stated",
        "branches": [], "assumptions": [], "needs_web": false,
        "steps": [["title": "Turns", "text": "Players take turns.",
                   "evidence": [["page": 1, "quote": "Players take turns.", "box": NSNull()]]]],
    ]

    override func setUp() async throws {
        continueAfterFailure = false
        let json = String(decoding: try JSONSerialization.data(withJSONObject: Self.answer), as: UTF8.self)
        stub = try StubServer(answerJSON: json)
        // A rulebook that isn't the sample, so the demo provider never answers it.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("server-route-\(UUID().uuidString).pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { ctx in
            ctx.beginPage()
            ("Some other game. Players take turns." as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }.write(to: url)
        pdfPath = url.path
    }

    override func tearDown() async throws {
        stub.stop()
    }

    /// `token` stands in for the bundled one; nil = a build without a bundled token.
    private func launch(token: String?, ask: String? = "Can I pass?") {
        var args = ["-pdfPath", pdfPath, "-isolatedCredentials", "YES", "-serverURL", stub.url]
        if let token { args += ["-appToken", token] }
        if let ask { args += ["-ask", ask] }
        app.launchArguments = args
        app.launch()
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func openMenu(_ item: String) {
        app.navigationBars.buttons["More"].firstMatch.tap()
        app.buttons[item].tap()
    }

    private func assertSentToServer(token: String, file: StaticString = #filePath, line: UInt = #line) {
        let posts = stub.seen.filter { $0.path == "/v1/messages" }
        XCTAssertFalse(posts.isEmpty, "no request reached the stub", file: file, line: line)
        for r in posts {
            XCTAssertEqual(r.headers["authorization"], "Bearer \(token)", file: file, line: line)
            XCTAssertNil(r.headers["x-api-key"], file: file, line: line)
        }
    }

    /// Default experience: the bundled token answers through the server, nothing to enter; Answer Details and
    /// Settings both say so.
    func testBundledTokenAnswersThroughServer() {
        launch(token: "fake-ok")
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["verdict"].label, "Yes, you may pass.")
        assertSentToServer(token: "fake-ok")
        XCTAssertTrue(app.buttons["closeAnswer"].waitForExistence(timeout: 5))

        openMenu("Answer Details")
        let route = app.staticTexts["answerRoute"]
        XCTAssertTrue(route.waitForExistence(timeout: 3))
        XCTAssertTrue(route.label.hasSuffix("ackshually server · 127.0.0.1"), route.label)
        app.buttons["Done"].tap()

        app.buttons["closeAnswer"].tap()
        // Settings lives on My Games (S1): Back, then the gear.
        app.navigationBars.buttons["My Games"].firstMatch.tap()
        app.buttons["settings"].tap()
        let active = app.staticTexts["activeRoute"]
        XCTAssertTrue(active.waitForExistence(timeout: 3))
        XCTAssertEqual(active.label, "Answers by ackshually server")
        XCTAssertEqual(app.staticTexts["activeRouteDetail"].label, "Built into this app · 127.0.0.1")
        // The developer options stay folded away when the app is set up.
        XCTAssertFalse(any("tokenOverrideField").exists)
    }

    /// No bundled token: asking opens Settings with the question kept; a token override saved there becomes
    /// the active route and answers through the server.
    func testTokenOverrideBecomesActiveRoute() {
        launch(token: nil)
        let active = app.staticTexts["activeRoute"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertEqual(active.label, "No answer service set up")
        let field = app.secureTextFields["tokenOverrideField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Developer section is open when nothing is set up")
        field.tap()
        field.typeText("fake-ok")
        app.buttons["tokenOverrideField.save"].tap()
        XCTAssertTrue(app.staticTexts["activeRoute"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["activeRoute"].label, "Answers by ackshually server")
        XCTAssertEqual(app.staticTexts["activeRouteDetail"].label, "Developer token · 127.0.0.1")
        XCTAssertTrue(app.buttons["tokenOverrideField.remove"].exists)
        app.navigationBars["Settings"].buttons["Done"].tap()

        // The question was kept in the ask field: send it.
        let send = app.buttons["send"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        send.tap()
        XCTAssertTrue(app.staticTexts["verdict"].waitForExistence(timeout: 10))
        assertSentToServer(token: "fake-ok")
    }

    /// A rejected token: the message points to Settings and its button opens it. Settings moved to My Games'
    /// toolbar (S1), but Open Settings still opens it right over the viewer, and Done returns to the answer.
    func testRevokedTokenPointsToSettings() {
        launch(token: "fake-revoked")
        let message = app.staticTexts["failureMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertEqual(message.label, "The server didn't accept your access token. It may be mistyped or revoked: check it in Settings.")
        app.buttons["failureSettings"].tap()
        XCTAssertTrue(app.staticTexts["activeRoute"].waitForExistence(timeout: 3))
        app.navigationBars["Settings"].buttons["Done"].tap()
        XCTAssertTrue(message.waitForExistence(timeout: 3), "back on the viewer with the failed answer")
        XCTAssertTrue(app.descendants(matching: .any)["pdfView"].firstMatch.exists)
        XCTAssertFalse(app.buttons["settings"].exists, "not dropped back to My Games")
    }

    /// 429s: the per-minute limit says when to retry; the daily cap says tomorrow. Neither offers Settings.
    func testRateLimitAndDailyCapMessages() {
        for (token, text) in [("fake-busy", "Too many questions at once. Try again in 30 seconds."),
                              ("fake-daily", "Today's question limit is reached. Try again tomorrow.")] {
            launch(token: token)
            let message = app.staticTexts["failureMessage"]
            XCTAssertTrue(message.waitForExistence(timeout: 10), token)
            XCTAssertEqual(message.label, text)
            XCTAssertFalse(app.buttons["failureSettings"].exists, token)
            XCTAssertTrue(app.buttons["Try Again"].exists, token)
            app.terminate()
        }
    }
}
