import XCTest
@testable import Ackshually

/// The sheet's detent heights (owner, 2026-11-22: "the panel hides and reappears" while an
/// answer streams): frozen while streaming once sized, then fitted to the finished content.
final class AnswerMetricsTests: XCTestCase {
    private let sized = AnswerMetrics(collapsed: 120, medium: 400)

    func testFirstMeasurementIsTakenWhileStreaming() {
        XCTAssertEqual(AnswerMetrics().next(measured: sized, streaming: true), sized)
    }

    func testFrozenWhileStreaming() {
        // Verdict replaces the taller "arriving" header, then a long step arrives: no change.
        XCTAssertEqual(sized.next(measured: AnswerMetrics(collapsed: 90, medium: 360), streaming: true), sized)
        XCTAssertEqual(sized.next(measured: AnswerMetrics(collapsed: 140, medium: 460), streaming: true), sized)
    }

    func testFitsContentOnceDone() {
        // Loading card gone (shorter) or branch rows in (taller): follow the content.
        let shorter = AnswerMetrics(collapsed: 100, medium: 330)
        let taller = AnswerMetrics(collapsed: 100, medium: 450)
        XCTAssertEqual(sized.next(measured: shorter, streaming: false), shorter)
        XCTAssertEqual(sized.next(measured: taller, streaming: false), taller)
    }

    func testPartialMeasurementKeepsMeasuringWhileStreaming() {
        // Medium not distinct yet (shelf not laid out): keep taking measurements.
        let partial = AnswerMetrics(collapsed: 120, medium: 120)
        XCTAssertEqual(partial.next(measured: sized, streaming: true), sized)
    }
}
