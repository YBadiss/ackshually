import XCTest
import PDFKit
@testable import AckshuallyCore

/// Several rulebooks per game (S13): joining the books in play, the page map back to (book, page), the
/// prompt's table of contents / order of authority / not-in-play note, and the size rule.
final class RulebookSetTests: XCTestCase {
    static let base: Data = {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("ackshually-base-\(UUID()).pdf")
        try! FixtureRulebook.write(to: u)
        return try! Data(contentsOf: u)
    }()

    static let expansion: Data = {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("ackshually-solar-\(UUID()).pdf")
        try! FixtureRulebook.write(to: u, pages: FixtureRulebook.expansionPages)
        return try! Data(contentsOf: u)
    }()

    private func joined(notInPlay: [String] = ["Storms"]) throws -> JoinedRulebook {
        try XCTUnwrap(RulebookJoiner.join([
            RulebookSource(title: "Power Plant Rush", role: .core, pdf: Self.base),
            RulebookSource(title: "Solar", role: .addOn, pdf: Self.expansion),
        ], gameTitle: "Power Plant Rush", notInPlay: notInPlay))
    }

    // MARK: Joining

    func testJoinPutsEachBooksPagesInARow() throws {
        let j = try joined()
        let doc = try XCTUnwrap(PDFDocument(data: j.pdf))
        XCTAssertEqual(doc.pageCount, 6)
        XCTAssertTrue(doc.page(at: 3)?.string?.contains("Battery") ?? false, "base page 4")
        XCTAssertTrue(doc.page(at: 4)?.string?.contains("Solar Expansion") ?? false, "then the add-on's page 1")
        XCTAssertTrue(doc.page(at: 5)?.string?.contains("keeps up to 3 unused energy") ?? false)
        XCTAssertEqual(j.contents.parts, [
            BookPart(title: "Power Plant Rush", role: .core, firstPage: 1, pageCount: 4),
            BookPart(title: "Solar", role: .addOn, firstPage: 5, pageCount: 2),
        ])
        XCTAssertEqual(j.contents.pageCount, 6)
    }

    func testOneBookIsSentUnchanged() throws {
        let j = try XCTUnwrap(RulebookJoiner.join([RulebookSource(title: "Power Plant Rush", role: .core, pdf: Self.base)],
                                                  gameTitle: "Power Plant Rush"))
        XCTAssertEqual(j.pdf, Self.base, "same bytes: the cache entry from before several books stays warm")
        XCTAssertFalse(j.contents.isJoined)
        XCTAssertFalse(j.contents.needsPromptNote)
        XCTAssertNil(AnswerRequest(books: j, question: "q").contents, "the request is exactly the single-book one")
    }

    func testUnreadableBookOrNoBooksGiveNothing() {
        XCTAssertNil(RulebookJoiner.join([], gameTitle: "G"))
        XCTAssertNil(RulebookJoiner.join([RulebookSource(title: "A", role: .core, pdf: Self.base),
                                          RulebookSource(title: "B", role: .addOn, pdf: Data("not a pdf".utf8))], gameTitle: "G"))
    }

    // MARK: Page map

    func testDocumentPagesMapBackToBookAndPage() throws {
        let c = try joined().contents
        XCTAssertEqual(c.reference(for: 4), PageReference(book: "Power Plant Rush", page: 4))
        XCTAssertEqual(c.reference(for: 5), PageReference(book: "Solar", page: 1))
        XCTAssertEqual(c.reference(for: 6).label, "Solar p.2")
        XCTAssertEqual(c.reference(for: 6).spokenLabel, "Solar, page 2")
        XCTAssertEqual(c.reference(for: 9), PageReference(book: nil, page: 9), "a page past the end keeps its number")
        XCTAssertEqual(c.documentPage(book: "Solar", page: 2), 6)
        XCTAssertNil(c.documentPage(book: "Solar", page: 3))
        XCTAssertNil(c.documentPage(book: "Storms", page: 1))
        XCTAssertEqual(c.partIndex(of: 5), 1)
    }

    func testOneBookLabelsHaveNoBookName() {
        let c = RulebookContents(gameTitle: "Azul", books: [("Azul", .core, 8)])
        XCTAssertEqual(c.reference(for: 3).label, "p.3")
        XCTAssertEqual(c.reference(for: 3).spokenLabel, "page 3")
    }

    // MARK: Prompt

    func testPromptNoteListsBooksAuthorityAndWhatIsNotInPlay() throws {
        let note = try joined().contents.promptNote
        XCTAssertTrue(note.contains(#"- pages 1–4: "Power Plant Rush" (core)"#), note)
        XCTAssertTrue(note.contains(#"- pages 5–6: "Solar" (add-on)"#), note)
        XCTAssertTrue(note.contains("errata and FAQs over a rules reference"), note)
        XCTAssertTrue(note.contains("a rules reference over a learning guide"), note)
        XCTAssertTrue(note.contains(#"Not in play tonight (add-ons the players did not pick): "Storms""#), note)
        XCTAssertTrue(note.contains(#"set confidence to "not_covered""#), note)
    }

    func testNoNotInPlayLineWhenEverythingIsTicked() throws {
        let note = try joined(notInPlay: []).contents.promptNote
        XCTAssertFalse(note.contains("Not in play"))
    }

    func testOneBookWithUntickedAddOnsStillNamesThem() {
        let c = RulebookContents(gameTitle: "Root", books: [("Law of Root", .core, 32)], notInPlay: ["Riverfolk"])
        XCTAssertTrue(c.needsPromptNote)
        XCTAssertTrue(c.promptNote.contains(#""Law of Root", the rulebook in play tonight"#))
        XCTAssertTrue(c.promptNote.contains(#""Riverfolk""#))
        XCTAssertFalse(c.promptNote.contains("joined"))
    }

    func testRequestSendsTheTableOfContentsBeforeTheDocument() throws {
        let p = ClaudeProvider(config: ClaudeConfig(apiKey: "x"))
        let body = p.requestBody(for: AnswerRequest(books: try joined(), question: "Battery?")).serialized()
        let toc = try XCTUnwrap(body.range(of: "joined into one file"))
        let doc = try XCTUnwrap(body.range(of: "application/pdf"))
        let question = try XCTUnwrap(body.range(of: "Battery?"))
        XCTAssertLessThan(toc.lowerBound, doc.lowerBound, "in the cached prefix, before the document")
        XCTAssertLessThan(doc.lowerBound, question.lowerBound)
        XCTAssertTrue(body.contains(#""title":"Power Plant Rush""#), "the document is titled after the game")

        let plain = p.requestBody(for: AnswerRequest(pdf: Self.base, documentTitle: "Power Plant Rush", question: "Battery?")).serialized()
        XCTAssertFalse(plain.contains("joined"))
        XCTAssertFalse(plain.contains("Not in play"))
    }

    // MARK: Size

    func testOversizeDocumentsAreNeverSentWhole() {
        var r = AnswerRequest(pdf: Data(count: ClaudeProvider.maxDocumentBytes + 1), documentTitle: "Root", question: "q")
        XCTAssertTrue(r.isOversize)
        XCTAssertEqual(PageSelectingProvider.effectiveSelection(for: r), .automatic(PageSelectingProvider.oversizeOptions))
        XCTAssertFalse(PageSelectingProvider.oversizeOptions.fallbackOnNotCovered, "the full PDF would be refused")

        r.pageSelection = .automatic(PageSelectionOptions(topK: 3, fallbackOnNotCovered: true))
        guard case .automatic(let o) = PageSelectingProvider.effectiveSelection(for: r) else { return XCTFail() }
        XCTAssertFalse(o.fallbackOnNotCovered)
        XCTAssertEqual(o.topK, 3)

        let small = AnswerRequest(pdf: Self.base, documentTitle: "T", question: "q")
        XCTAssertEqual(PageSelectingProvider.effectiveSelection(for: small), .fullDocument)
    }

    /// A joined document sent as an excerpt: evidence comes back as pages of the joined document, which the
    /// page map turns into (book, page).
    func testExcerptOfAJoinedDocumentResolvesToBookPages() throws {
        let j = try joined()
        let book = try XCTUnwrap(RulebookIndex(data: j.pdf))
        let sel = book.selection(pages: [3, 6])
        // The model counted excerpt positions (2 = second page sent) and quoted the add-on's Battery rule.
        let page = book.resolvePage(Evidence(page: 2, quote: "keeps up to 3 unused energy"), in: sel)
        XCTAssertEqual(page, 6)
        XCTAssertEqual(j.contents.reference(for: page).label, "Solar p.2")
    }

    func testExcerptNoteOnlyPromisesTheFullBookWhenItFollows() {
        let sel = PageSelection(pages: [2, 4], pageCount: 9)
        XCTAssertTrue(sel.excerptNote(title: "T").contains("the full rulebook will then be checked"))
        XCTAssertFalse(sel.excerptNote(title: "T", fullDocumentFollows: false).contains("the full rulebook will then be checked"))
    }
}
