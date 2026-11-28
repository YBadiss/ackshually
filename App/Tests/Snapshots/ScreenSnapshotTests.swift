import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// Reference images of the screens' main states, built from the same fixtures as the `#Preview`s
/// (Power Plant Rush, the demo answer): a hand-picked list, not every preview, so the images stay few
/// and each one is worth reviewing. A failure attaches the reference, the new image and the diff.
/// Recorded on iOS 27.2 (`SnapshotRuntime`); other runtimes skip.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private static let phone = CGSize(width: 402, height: 874)

    private func snap(_ name: String, size: CGSize = phone, typeSize: DynamicTypeSize = .large, dark: Bool = false,
                      safeArea: Bool = false, testName: String = #function, line: UInt = #line,
                      @ViewBuilder _ content: () -> some View) async throws {
        let h = HostedView(size: size, typeSize: typeSize, dark: dark, safeArea: safeArea, content)
        defer { h.close() }
        await h.settle()
        try assertScreen(h, named: name, testName: testName, line: line)
    }

    /// Outside the system sheet the scroll view draws its soft top edge over the verdict (in the app it
    /// sits under the grabber); hidden here so the images show the content.
    private func column(_ model: ViewerModel, _ placement: AnswerPlacement) -> some View {
        AnswerContent(model: model, voice: AskController(), placement: placement)
            .scrollEdgeEffectHidden(true, for: .top)
            .themeBackground(\.sheet)
    }

    // MARK: Answer (S4–S9)

    func testAnswerColumn() async throws {
        try await snap("medium") { column(Fixtures.model(), .sheet(.medium)) }
        try await snap("streaming") { column(Fixtures.model(.streaming), .sheet(.medium)) }
        try await snap("expanded") { column(Fixtures.model(), .sheet(.expanded)) }
        try await snap("branch-dark", dark: true) { column(Fixtures.model(.branch), .sheet(.medium)) }
        try await snap("medium-ax5", typeSize: .accessibility5) { column(Fixtures.model(), .sheet(.medium)) }
    }

    func testAnswerHeaderStates() async throws {
        try await snap("states", size: CGSize(width: 402, height: 1500)) {
            VStack(spacing: 28) {
                AnswerHeader(content: Fixtures.headerArriving)
                AnswerHeader(content: Fixtures.headerStated)
                AnswerHeader(content: Fixtures.headerInferred)
                AnswerHeader(content: Fixtures.headerNotCovered)
                AnswerHeader(content: Fixtures.headerBranchActive)
                AnswerHeader(content: Fixtures.headerLongVerdict)
                AnswerHeader(content: Fixtures.headerFailed, onSettings: {})
            }
            .padding(20).frame(maxHeight: .infinity, alignment: .top).themeBackground(\.sheet)
        }
    }

    func testStepCardStates() async throws {
        try await snap("states", size: CGSize(width: 402, height: 1100)) {
            VStack(spacing: 12) {
                ForEach(Array(Fixtures.cardStates.enumerated()), id: \.offset) { _, c in StepCard(content: c) }
            }
            .padding(20).frame(maxHeight: .infinity, alignment: .top).themeBackground(\.sheet)
        }
    }

    // MARK: Viewer (S6–S8)

    func testViewerLandscape() async throws {
        let model = Fixtures.model()
        let h = ViewerLayoutTests.viewer(model, size: CGSize(width: 874, height: 402))
        defer { h.close() }
        _ = await h.settle { h.element("pdfView")?.value.hasPrefix("Zoomed, spotlight") == true }
        await h.settle()
        await h.settleRendering()
        try assertScreen(h, named: "answer-column")
    }

    func testHighlightOverlay() async throws {
        try await snap("states", size: CGSize(width: 402, height: 360)) {
            VStack(spacing: 16) {
                HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: nil) {}
                HighlightOverlay(evidenceIndex: 0, evidenceCount: 1, note: "See the diagram, lower half") {}
                HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial) {}
                HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.notFoundNote, noteKind: .miss) {}
            }
            .padding(.vertical).frame(maxHeight: .infinity, alignment: .top).background(Fixtures.pageBackdrop)
        }
    }

    // MARK: Several rulebooks (S13)

    func testPlayingWith() async throws {
        try await snap("play", safeArea: true) { PlayingWithFixtures.sheet(PlayingWithFixtures.content) }
        try await snap("play-dark", dark: true, safeArea: true) { PlayingWithFixtures.sheet(PlayingWithFixtures.content) }
    }

    // MARK: Adding rulebooks (S14)

    func testAddRulebooks() async throws {
        try await snap("suggested", safeArea: true) { AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested) }
        try await snap("sorting", safeArea: true) { AddRulebooksFixtures.sheet(AddRulebooksFixtures.sorting) }
        try await snap("unsorted-dark", dark: true, safeArea: true) { AddRulebooksFixtures.sheet(AddRulebooksFixtures.unsorted) }
    }

    /// Book names on the proof line, the cards and the pager when two books are joined.
    func testSeveralBooksAnswer() async throws {
        try await snap("medium") { column(Fixtures.setModel(card: 1), .sheet(.medium)) }
        try await snap("pager", size: CGSize(width: 402, height: 200)) {
            VStack(spacing: 16) {
                HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: nil, location: "Solar Expansion p.2") {}
                HighlightOverlay(evidenceIndex: 1, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial,
                                 location: "Power Plant Rush p.3") {}
            }
            .padding(.vertical).frame(maxHeight: .infinity, alignment: .top).background(Fixtures.pageBackdrop)
        }
    }

    // MARK: My Games, Settings, Answer Details

    func testLibrary() async throws {
        try await snap("games", safeArea: true) { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()) }
        try await snap("selecting", safeArea: true) { LibraryFixtures.selecting(selected: ["tile-garden.pdf", "woodland-court.pdf"]) }
        try await snap("empty", safeArea: true) { LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController()) }
        try await snap("empty-dark", dark: true, safeArea: true) {
            LibraryScreen(library: LibraryFixtures.model(games: []), voice: AskController())
        }
    }

    func testSettings() async throws {
        try await snap("bundled-token", safeArea: true) {
            SettingsView(status: Fixtures.routeBundled, demo: .constant(false), onSave: { _, _ in }, onRemove: { _ in }, onDone: {})
        }
        try await snap("nothing-set-up", safeArea: true) {
            SettingsView(status: Fixtures.routeNone, demo: .constant(false), onSave: { _, _ in }, onRemove: { _ in }, onDone: {})
        }
    }

    func testAnswerDetails() async throws {
        try await snap("reports", safeArea: true) {
            AnswerDetailsView(reports: Fixtures.evidenceReports, route: "ackshually server · ackshually.badyass.xyz", onCopy: {}, onDone: {})
        }
    }
}
