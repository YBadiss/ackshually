import XCTest
import PDFKit
@testable import Ackshually

/// S8 double-tap: PDFKit's own double-tap (zoom to fit width) used to fire together with ours, so the
/// page jumped to fit width and our zoom animated from there. Ours must win.
@MainActor
final class PDFViewerGestureTests: XCTestCase {
    private func attached() -> (PDFViewer.Coordinator, UITapGestureRecognizer) {
        let c = PDFViewer.Coordinator()
        let v = FitPagePDFView()
        c.attach(to: v)
        let ours = v.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }
            .first { $0.numberOfTapsRequired == 2 && $0.delegate === c }
        return (c, ours!)
    }

    func testPDFKitDoubleTapWaitsForOurs() {
        let (c, ours) = attached()
        let pdfKitDoubleTap = UITapGestureRecognizer()
        pdfKitDoubleTap.numberOfTapsRequired = 2
        XCTAssertTrue(c.gestureRecognizer(ours, shouldBeRequiredToFailBy: pdfKitDoubleTap))
        XCTAssertFalse(c.gestureRecognizer(ours, shouldRecognizeSimultaneouslyWith: pdfKitDoubleTap))
    }

    func testOtherGesturesStillRunAlongside() {
        let (c, ours) = attached()
        let singleTap = UITapGestureRecognizer()
        XCTAssertFalse(c.gestureRecognizer(ours, shouldBeRequiredToFailBy: singleTap))
        XCTAssertTrue(c.gestureRecognizer(ours, shouldRecognizeSimultaneouslyWith: singleTap))
        XCTAssertTrue(c.gestureRecognizer(ours, shouldRecognizeSimultaneouslyWith: UIPinchGestureRecognizer()))
    }
}
