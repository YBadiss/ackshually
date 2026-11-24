import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// The viewer and the screens around it, hosted in-process: phone landscape (answer column, PDF zoom,
/// the darker navigation bar), the chrome over the PDF, Answer Details, Settings and My Games' empty
/// state. Gestures, PDF pan/zoom and spotlight on the running app, navigation and the server route
/// stay in the UI tests.
@MainActor
final class ViewerLayoutTests: XCTestCase {
    private static let landscape = CGSize(width: 874, height: 402)
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    /// The viewer as `LibraryScreen` pushes it, on the sample rulebook with real highlight placement.
    static func viewer(_ model: ViewerModel, size: CGSize, dark: Bool = false) -> HostedView {
        HostedView(size: size, dark: dark, sizeClass: .compact) {
            NavigationStack {
                AdaptiveViewerLayout(model: model, voice: AskController(), document: model.rulebook.pdf, windowSize: size)
                    .navigationTitle(model.rulebook.title).navigationBarTitleDisplayMode(.inline)
                    .viewerChrome()
            }
        }
    }

    /// Phone landscape: the answer is a trailing column (no sheet) with a Hide/Show Answer button; the
    /// rulebook opens on the whole page, the answer zooms to its evidence, closing goes back to the whole
    /// page. The navigation bar is clearly darker than the column next to it (owner, 2026-11-21).
    func testLandscapeColumnZoomAndDarkerBar() async throws {
        let model = Fixtures.model(.idle)
        let h = Self.viewer(model, size: Self.landscape)
        host = h
        await h.settle()
        XCTAssertEqual(h.element("pdfView")?.value, "Whole page", "a rulebook opens on the whole page")

        model.present(LiveAnswer(question: batteryQuestion, answer: battery), phase: .done)
        let zoomed = await h.settle { h.element("pdfView")?.value.hasPrefix("Zoomed, spotlight") == true }
        XCTAssertTrue(zoomed, "evidence zoom with a spotlight: \(h.element("pdfView")?.value ?? "nil")")
        let verdict = try XCTUnwrap(h.frame("verdict"), "the answer is in the column")
        XCTAssertGreaterThan(verdict.minX, h.window.bounds.width / 2)
        XCTAssertNotNil(h.frame("toggleAnswer"))
        XCTAssertEqual(model.presentation.answerSheetPresented, false, "no sheet in landscape")

        let image = h.image(scale: 1)
        let bar = try XCTUnwrap(luma(image, at: CGPoint(x: verdict.minX, y: 8)))
        let column = try XCTUnwrap(luma(image, at: CGPoint(x: verdict.minX - 8, y: verdict.maxY + 8)))
        XCTAssertLessThan(bar, column - 0.04, "bar \(bar) vs column \(column)")

        model.dismissSheet()
        let whole = await h.settle { h.element("pdfView")?.value == "Whole page" }
        XCTAssertTrue(whole, "closing the answer shows the whole page again")
        XCTAssertNil(h.frame("verdict"))
    }

    /// Relative luminance (0–1) of the pixel at a window point (image at 1×).
    private func luma(_ image: UIImage, at p: CGPoint) -> CGFloat? {
        guard let cg = image.cgImage, let px = cg.cropping(to: CGRect(x: Int(p.x), y: Int(p.y), width: 1, height: 1)) else { return nil }
        var rgba = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(px, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * CGFloat(rgba[0]) + 0.7152 * CGFloat(rgba[1]) + 0.0722 * CGFloat(rgba[2])) / 255
    }

    /// The note and the "Quote 1 of 2 ›" pager over the PDF never overlap and stay on screen, on a
    /// small and a large phone, at default and accessibility text sizes.
    func testHighlightNoteNeverOverlapsThePager() async throws {
        for width in [CGFloat(375), 402] {
            for size in [DynamicTypeSize.large, .accessibility3] {
                let h = HostedView(size: CGSize(width: width, height: 300), typeSize: size) {
                    HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial) {}
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                await h.settle()
                let note = try XCTUnwrap(h.element("highlightNote")), pager = try XCTUnwrap(h.element("evidencePager"))
                XCTAssertEqual(note.label, HighlightPlacer.partialNote)
                XCTAssertEqual(pager.label, "Quote 1 of 2")
                XCTAssertFalse(note.frame.intersects(pager.frame), "note \(note.frame) overlaps pager \(pager.frame) at \(width) pt, \(size)")
                for f in [note.frame, pager.frame] {
                    XCTAssertTrue(h.window.bounds.contains(f), "\(f) off screen at \(width) pt, \(size)")
                }
                h.close()
            }
        }
    }

    /// ⋯ → Answer Details names each passage's match status and how many are highlighted.
    func testAnswerDetailsListsMatchStatus() async throws {
        let h = HostedView(size: CGSize(width: 402, height: 1600), safeArea: true) {
            AnswerDetailsView(reports: Fixtures.evidenceReports, route: "Demo answers", onCopy: {}, onDone: {})
        }
        host = h
        await h.settle()
        let status = { (id: String) in h.element("evidence-\(id)")?.label ?? "missing" }
        XCTAssertTrue(status("1.1").hasPrefix("Matched"), status("1.1"))
        XCTAssertTrue(status("2.4").hasPrefix("Partly matched"), status("2.4"))
        XCTAssertTrue(status("2.2").hasPrefix("Not matched"), status("2.2"))
        let spotlit = Fixtures.evidenceReports.count(where: { $0.match?.isSpotlit == true })
        XCTAssertEqual(h.element("detailsSummary")?.label, "\(spotlit) of \(Fixtures.evidenceReports.count) passages highlighted")
        XCTAssertTrue(h.element("answerRoute")?.label.contains("Demo answers") == true)
    }

    /// Settings: the Developer options are open when nothing is set up (the way to fix it is on screen)
    /// and folded away when the built-in token answers.
    func testSettingsOpensDeveloperOptionsOnlyWhenNothingIsSetUp() async throws {
        for (status, open) in [(Fixtures.routeNone, true), (Fixtures.routeBundled, false)] {
            let h = HostedView(size: CGSize(width: 402, height: 1400), safeArea: true) {
                SettingsView(status: status, demo: .constant(false), onSave: { _, _ in }, onRemove: { _ in }, onDone: {})
            }
            await h.settle()
            XCTAssertEqual(h.frame("tokenOverrideField") != nil, open, "\(status.active)")
            XCTAssertEqual(h.frame("apiKeyField") != nil, open, "\(status.active)")
            h.close()
        }
    }

    /// My Games, empty: "No Games Yet" with Add a Rulebook and Try the Sample; ＋ and Settings in the toolbar.
    func testEmptyLibraryOffersAddAndSample() async throws {
        let h = HostedView(size: CGSize(width: 402, height: 874), safeArea: true) {
            LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController())
        }
        host = h
        await h.settle()
        XCTAssertTrue(h.elements.contains { $0.label == "No Games Yet" })
        for id in ["emptyAddRulebook", "trySample", "addRulebook", "settings"] {
            XCTAssertNotNil(h.frame(id), id)
        }
    }
}
