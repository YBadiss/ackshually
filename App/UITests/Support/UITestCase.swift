import XCTest

/// Shared UI-test plumbing: screenshots, drags, waits and generated demo answers. Each test class sets its
/// launch arguments. Set SCREENSHOT_DIR in the test environment to also save PNGs.
@MainActor
class UITestCase: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment.merge(Self.forwardedEnvironment) { _, new in new }
    }

    /// Runner variables named `APP_X` reach the app as `X`, so a debugging switch can be set from the command
    /// line: `TEST_RUNNER_APP_AG_TRAP_CYCLES=1 xcodebuild test …` (xcodebuild strips `TEST_RUNNER_`).
    nonisolated static var forwardedEnvironment: [String: String] {
        var env: [String: String] = [:]
        for (key, value) in ProcessInfo.processInfo.environment where key.hasPrefix("APP_") {
            env[String(key.dropFirst(4))] = value
        }
        return env
    }

    /// The sample rulebook with demo answers, instant by default (`-demoPace 0`: the whole answer at once).
    func launchSample(_ args: [String], pace: Double = 0) {
        app.launchArguments = ["-sample", "YES", "-demo", "YES", "-demoPace", "\(pace)"] + args
        app.launch()
    }

    func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    var verdict: XCUIElement { app.staticTexts["verdict"] }
    var dots: XCUIElement { any("cardDots") }
    var pdf: XCUIElement { any("pdfView") }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name; a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// Waits until `predicate` (NSPredicate format, e.g. "label == %@") holds for `element`.
    @discardableResult
    func wait(_ element: XCUIElement, _ format: String, _ args: Any..., timeout: TimeInterval = 3) -> Bool {
        let p = NSPredicate(format: format, argumentArray: args)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: element)], timeout: timeout) == .completed
    }

    func waitForCard(_ label: String, timeout: TimeInterval = 5) -> Bool { wait(dots, "label == %@", label, timeout: timeout) }

    func waitHittable(_ e: XCUIElement, _ hittable: Bool = true, timeout: TimeInterval = 3) -> Bool {
        wait(e, "hittable == %@", NSNumber(value: hittable), timeout: timeout)
    }

    /// Drags from an element to a point at `y` (fraction of the window height).
    func drag(_ e: XCUIElement, toY y: CGFloat) {
        let start = e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Writes a spec §4 answer for `-demoAnswer`, one passage per step (the sample rulebook's pages
    /// 3–4 hold the quotes).
    func demoAnswer(verdict: String, steps: [(title: String, text: String, page: Int, quote: String)]) throws -> String {
        let json: [String: Any] = [
            "restated_question": "What happens to unused energy?", "verdict": verdict, "confidence": "stated",
            "steps": steps.map { s in
                ["title": s.title, "text": s.text, "evidence": [["page": s.page, "quote": s.quote, "box": NSNull()]]]
            },
            "branches": [], "assumptions": [], "needs_web": false,
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url.path
    }

    static let goodQuote = "you must discard all unused energy"
    static let missingQuote = "players may trade energy freely during the auction phase of the game"
}
