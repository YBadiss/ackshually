import Foundation
import OSLog

/// This test process's own unified log (the app is the test host, so its views log here): lets an in-process
/// test fail on a console message, the same messages `App/TestPlans/console-check.sh` fails on in the UI tests.
enum ConsoleLog {
    /// Messages logged since `start` whose text contains one of `patterns`.
    static func messages(since start: Date, containing patterns: [String]) throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        return try store.getEntries(at: store.position(date: start))
            .compactMap { $0 as? OSLogEntryLog }
            .map(\.composedMessage)
            .filter { m in patterns.contains { m.contains($0) } }
    }

    /// SwiftUI / AttributeGraph messages that always mean a bug in our views.
    static let viewBugs = ["Cycle detected through attribute", "AttributeGraph: cycle detected",
                           "Observation tracking feedback loop", "multiple times per frame",
                           "Publishing changes from within view updates", "Modifying state during view update"]
}
