import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// My Games (S1) hosted in-process: the undo bar after a delete.
@MainActor
final class LibraryLayoutTests: XCTestCase {
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    private func screen(_ library: LibraryModel, size: CGSize = CGSize(width: 375, height: 812),
                        typeSize: DynamicTypeSize = .large) async -> HostedView {
        let h = HostedView(size: size, typeSize: typeSize, safeArea: true) {
            LibraryScreen(library: library, voice: AskController())
        }
        host = h
        await h.settle()
        return h
    }

    /// Browsing: Settings leading, Select and ＋ trailing (#25: "Select", not "Edit").
    func testBrowsingToolbar() async throws {
        let h = await screen(LibraryFixtures.model())
        let width = h.window.bounds.width
        let settings = try XCTUnwrap(h.frame("settings")), select = try XCTUnwrap(h.element("selectGames"))
        XCTAssertLessThan(settings.midX, width / 2)
        XCTAssertGreaterThan(select.frame.midX, width / 2)
        XCTAssertEqual(select.label, "Select")
        XCTAssertNotNil(h.frame("addRulebook"))
    }

    /// Selecting, like Files and Photos (#25): Select All leading and Done trailing; Settings and ＋ gone, not
    /// dimmed; "N Selected" and the trash at the bottom, the trash on the trailing side.
    func testSelectingToolbar() async throws {
        for typeSize in [DynamicTypeSize.large, .accessibility3] {
            let h = HostedView(size: CGSize(width: 375, height: 812), typeSize: typeSize, safeArea: true) {
                LibraryFixtures.selecting(selected: ["tile-garden.pdf", "woodland-court.pdf"])
            }
            host = h
            await h.settle()
            let bounds = h.window.bounds
            XCTAssertNil(h.frame("settings"), "Settings is hidden while selecting (\(typeSize))")
            XCTAssertNil(h.frame("addRulebook"), "＋ is hidden while selecting (\(typeSize))")
            let selectAll = try XCTUnwrap(h.element("selectAll"), "\(typeSize)")
            XCTAssertEqual(selectAll.label, "Select All")
            XCTAssertLessThan(selectAll.frame.midX, bounds.midX)
            let done = try XCTUnwrap(h.element("selectGames"), "\(typeSize)")
            XCTAssertEqual(done.label, "Done")
            XCTAssertGreaterThan(done.frame.midX, bounds.midX)
            XCTAssertEqual(h.element("selectedCount")?.label, "2 Selected")
            let trash = try XCTUnwrap(h.frame("deleteSelected"), "\(typeSize)")
            XCTAssertGreaterThan(trash.midX, bounds.width * 0.7, "trash on the trailing side (\(typeSize))")
            XCTAssertGreaterThan(trash.midY, bounds.height * 0.8, "trash in the bottom bar (\(typeSize))")
            XCTAssertEqual(h.element("deleteSelected")?.label, "Delete")
            for g in LibraryFixtures.games {
                guard let f = h.frame("game-\(g.id)") else { continue }
                XCTAssertLessThanOrEqual(f.maxX, bounds.width + 0.5, "\(g.title) inside the screen (\(typeSize))")
            }
            h.close()
        }
    }

    /// After a delete, "Deleted <game> · Undo" sits at the bottom, inside the screen, with a 44 pt Undo; Undo
    /// brings the game back and the bar goes (#28).
    func testUndoBarAfterADelete() async throws {
        for typeSize in [DynamicTypeSize.large, .accessibility3] {
            let library = LibraryFixtures.model()
            let game = library.games[0]
            library.delete([game])
            let h = await screen(library, typeSize: typeSize)
            let bar = try XCTUnwrap(h.frame("undoBar"), "no undo bar (\(typeSize))")
            XCTAssertTrue(h.elements.contains { $0.label == "Deleted \(game.title)" }, "\(typeSize)")
            XCTAssertTrue(h.window.bounds.contains(bar), "bar \(bar) inside the screen (\(typeSize))")
            XCTAssertGreaterThan(bar.midY, h.window.bounds.midY, "at the bottom (\(typeSize))")
            let undo = try XCTUnwrap(h.frame("undoDelete"))
            XCTAssertGreaterThanOrEqual(undo.height, 44, "\(typeSize)")
            XCTAssertGreaterThanOrEqual(undo.width, 44, "\(typeSize)")

            library.undo(try XCTUnwrap(library.undoBar))
            await h.settle()
            XCTAssertNil(h.frame("undoBar"))
            XCTAssertEqual(library.games.first, game)
            h.close()
        }
    }
}
