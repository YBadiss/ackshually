import XCTest
import SwiftUI
import PDFKit
@testable import Ackshually

/// S13: ticking or unticking an add-on gives the open viewer a new joined PDF. Swapping `PDFView.document`
/// removes the old page views, and after a tap on the page one of them is the first responder: UIKit resigns
/// it, SwiftUI's hosting view re-enters the view graph in the middle of the update, and AttributeGraph logs
/// "Cycle detected through attribute" (×7, the owner's console, 2026-11-24: reopening Root after unticking
/// Underworld).
@MainActor
final class PDFDocumentSwapTests: XCTestCase {
    private func copy(of document: PDFDocument) throws -> PDFDocument {
        try XCTUnwrap(document.dataRepresentation().flatMap(PDFDocument.init(data:)))
    }

    func testSwappingTheDocumentWhileAPageIsFirstResponderLogsNoCycle() async throws {
        let holder = PDFDocumentSwapHolder(try copy(of: Fixtures.pdf))
        let h = HostedView(size: CGSize(width: 402, height: 874)) { PDFDocumentSwapHost(holder: holder) }
        defer { h.close() }
        h.window.makeKey()
        await h.settle()
        // A tap on the page makes PDFKit's document view first responder.
        let pageView = try XCTUnwrap(Self.descendants(of: h.window).first { String(describing: type(of: $0)).contains("PDFDocumentView") })
        XCTAssertTrue(pageView.becomeFirstResponder(), "the page view takes first responder, as after a tap")

        let start = Date()
        holder.document = try copy(of: Fixtures.pdf)
        await h.settle()
        let shown = await h.settle { (Self.descendants(of: h.window).first { $0 is PDFView } as? PDFView)?.document === holder.document }
        XCTAssertTrue(shown, "the new document is shown")
        let bugs = try ConsoleLog.messages(since: start, containing: ConsoleLog.viewBugs)
        XCTAssertEqual(bugs, [], "console while swapping the document")
    }

    static func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}

/// The document the hosted viewer shows; the test swaps it.
@Observable
fileprivate final class PDFDocumentSwapHolder {
    var document: PDFDocument
    init(_ document: PDFDocument) { self.document = document }
}

fileprivate struct PDFDocumentSwapHost: View {
    var holder: PDFDocumentSwapHolder
    var body: some View {
        PDFViewer(document: holder.document, bottomObscured: 0, onUserMove: {}, onDoubleTap: {})
    }
}
