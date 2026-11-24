import XCTest
import SwiftUI
@testable import Ackshually

/// The environment only skips re-rendering for an unchanged theme if it can compare themes:
/// `ThemeProvider` rebuilds it on every pass (see `Theme`).
final class ThemeTests: XCTestCase {
    func testRebuiltThemeEqualsItself() {
        XCTAssertEqual(Theme.warm.scaled(for: .large), Theme.warm.scaled(for: .large))
        XCTAssertNotEqual(Theme.warm.scaled(for: .large), Theme.warm.scaled(for: .accessibility3))
    }
}
