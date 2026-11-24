import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// Several rulebooks per game (S13), hosted in-process: the "Playing with" list, the viewer's
/// title button and book switcher, book names on the pager and the cards, and "N rulebooks" in My Games.
@MainActor
final class RulebookSetLayoutTests: XCTestCase {
    private static let phone = CGSize(width: 402, height: 874)
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    private func hosted(size: CGSize = phone, typeSize: DynamicTypeSize = .large, safeArea: Bool = true,
                        @ViewBuilder _ content: () -> some View) async -> HostedView {
        host?.close()
        let h = HostedView(size: size, typeSize: typeSize, safeArea: safeArea, content)
        host = h
        await h.settle()
        return h
    }

    /// Core books are checked and can't be unticked; add-ons say whether they're in play; Play and
    /// ＋ Add a Rulebook are on screen; every row stays inside the screen at the largest text size.
    func testPlayingWithListsEveryBookWithPlayAndAdd() async throws {
        for size in [DynamicTypeSize.large, .accessibility5] {
            let h = await hosted(typeSize: size) { PlayingWithFixtures.sheet(PlayingWithFixtures.content) }
            let core = try XCTUnwrap(h.element("book-\(PlayingWithFixtures.sampleID)"))
            XCTAssertEqual(core.value, "Always in play")
            XCTAssertEqual(h.element("book-\(Library.sampleExpansionFileName)")?.value, "Playing with")
            XCTAssertEqual(h.element("book-storms.pdf")?.value, "Not tonight")
            XCTAssertNotNil(h.frame("playingWithConfirm"), "Play (\(size))")
            XCTAssertEqual(h.element("playingWithConfirm")?.label, "Play")
            for b in PlayingWithFixtures.content.core + PlayingWithFixtures.content.addOns {
                guard let f = h.frame("book-\(b.fileName)") else { continue }  // scrolled below at AX5
                XCTAssertLessThanOrEqual(f.maxX, h.window.bounds.width + 0.5, "\(b.title) runs off screen at \(size)")
                XCTAssertGreaterThanOrEqual(f.minX, -0.5)
            }
        }
        let h = await hosted { PlayingWithFixtures.sheet(PlayingWithFixtures.content) }
        XCTAssertNotNil(h.frame("addBook"), "＋ Add Rulebooks at the bottom")
    }

    func testFromTheViewerItSaysDoneAndWhileOpeningItShowsProgress() async throws {
        var h = await hosted { PlayingWithFixtures.sheet(PlayingWithFixtures.oneBook) }
        XCTAssertEqual(h.element("playingWithConfirm")?.label, "Done")
        XCTAssertFalse(h.elements.contains { $0.label == "Close" }, "no Close from the viewer: Done is the way out")
        h = await hosted { PlayingWithFixtures.sheet(PlayingWithFixtures.opening) }
        XCTAssertNil(h.frame("playingWithConfirm"), "Play is replaced by progress while the books are joined")
        XCTAssertTrue(h.elements.contains { $0.label == "Opening the rulebooks" })
    }

    /// The viewer's title is a button with the ticked add-ons; several books in play add the book switcher.
    func testViewerTitleButtonAndBookSwitcher() async throws {
        var h = await hosted {
            NavigationStack {
                ViewerScreen(model: Fixtures.setModel(answered: false), voice: AskController(), windowSize: Self.phone,
                             title: "Power Plant Rush · Solar Expansion")
            }
        }
        XCTAssertEqual(h.element("gameTitleButton")?.label, "Power Plant Rush · Solar Expansion")
        XCTAssertNotNil(h.frame("bookSwitcher"))

        h = await hosted {
            NavigationStack {
                ViewerScreen(model: Fixtures.model(.idle), voice: AskController(), windowSize: Self.phone, title: "Power plant rush")
            }
        }
        XCTAssertNotNil(h.frame("gameTitleButton"), "a one-book game can still add books from its title")
        XCTAssertNil(h.frame("bookSwitcher"), "nothing to switch between")
    }

    /// The pager names the book when several are joined, and still fits on a small phone at large text.
    func testPagerNamesTheBookAndFits() async throws {
        for size in [DynamicTypeSize.large, .accessibility3] {
            let h = await hosted(size: CGSize(width: 375, height: 300), typeSize: size, safeArea: false) {
                HighlightOverlay(evidenceIndex: 0, evidenceCount: 2, note: HighlightPlacer.partialNote, noteKind: .partial,
                                 location: "Solar Expansion p.2") {}
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            let pager = try XCTUnwrap(h.element("evidencePager"))
            XCTAssertEqual(pager.label, "Quote 1 of 2 · Solar Expansion p.2")
            XCTAssertTrue(h.window.bounds.contains(pager.frame), "\(pager.frame) off screen at \(size)")
            let note = try XCTUnwrap(h.element("highlightNote"))
            XCTAssertFalse(note.frame.intersects(pager.frame))
        }
    }

    /// Step cards show "Solar Expansion p.2" in the caption; the caption stays inside its card.
    func testCardCaptionNamesTheBook() async throws {
        let v = Fixtures.setModel(card: 1)
        let h = await hosted(safeArea: false) {
            AnswerContent(model: v, voice: AskController(), placement: .sheet(.medium)).themeBackground(\.sheet)
        }
        XCTAssertTrue(h.elements.contains { $0.label.contains("Solar Expansion p.2") }, "card caption")
        let proof = try XCTUnwrap(h.element("proofLine"))
        XCTAssertTrue(proof.label.contains("Solar Expansion, page 2"), proof.label)
    }

    func testMyGamesRowSaysHowManyRulebooks() async throws {
        let h = await hosted { LibraryScreen(library: LibraryFixtures.model(), voice: AskController()) }
        let row = try XCTUnwrap(h.element("game-woodland-court.pdf"))
        XCTAssertTrue(row.label.contains("7 rulebooks"), row.label)
        XCTAssertFalse(h.element("game-tile-garden.pdf")?.label.contains("rulebooks") ?? true, "one book: no count")
    }
}
