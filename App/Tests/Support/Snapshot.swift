import XCTest
import SnapshotTesting
import UIKit

/// Reference images are recorded on one pinned runtime: text rendering changes between iOS
/// versions, so another runtime would fail every image. The window size is fixed by each test, so
/// the simulator model doesn't matter. Reference images may only show fixtures and the generated
/// sample rulebook (Power Plant Rush), never a real rulebook page.
enum SnapshotRuntime {
    static let pinned = "27.2"
    /// Rendered at 2× whatever the simulator: crisp enough to review, half the bytes of 3×.
    static let scale: CGFloat = 2
}

extension XCTestCase {
    /// Compares the hosted window with `__Snapshots__/<TestClass>/<test>.<name>.png`. A missing
    /// reference is recorded (and the test fails once); re-record all with
    /// `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild test …`.
    @MainActor
    func assertScreen(_ host: HostedView, named name: String,
                      file: StaticString = #filePath, testName: String = #function, line: UInt = #line) throws {
        let os = UIDevice.current.systemVersion
        guard os == SnapshotRuntime.pinned || os.hasPrefix(SnapshotRuntime.pinned + ".") else {
            throw XCTSkip("Snapshots are recorded on iOS \(SnapshotRuntime.pinned); this simulator runs \(os).")
        }
        // Tiny antialiasing differences between machines pass; a moved or recoloured element doesn't.
        assertSnapshot(of: host.image(scale: SnapshotRuntime.scale), as: .image(precision: 0.995, perceptualPrecision: 0.98),
                       named: name, file: file, testName: testName, line: line)
    }
}
