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
