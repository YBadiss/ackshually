import XCTest
import PDFKit
@testable import AckshuallyCore

final class RetrievalTextTests: XCTestCase {
    func testStemsAreConsistentAcrossInflections() {
        let s = RetrievalText.stem
        XCTAssertEqual(s("moves"), s("move"))
        XCTAssertEqual(s("moving"), s("move"))
        XCTAssertEqual(s("moved"), s("move"))
        XCTAssertEqual(s("ties"), s("tie"))
        XCTAssertEqual(s("tied"), s("tie"))
        XCTAssertEqual(s("plants"), s("plant"))
        XCTAssertEqual(s("passing"), s("pass"))
        XCTAssertEqual(s("rules"), s("rule"))
        XCTAssertEqual(s("ruling"), s("rule"))
        XCTAssertEqual(s("players"), s("player"))
    }

    func testTermsFoldCaseDropStopWordsAndAddBigrams() {
        XCTAssertEqual(RetrievalText.terms("Can I take MY Reveal turn?"), ["tak", "reveal", "turn"])
        XCTAssertEqual(RetrievalText.indexTerms("reveal turn"), ["reveal", "turn", "reveal_turn"])
        XCTAssertEqual(RetrievalText.terms("Élektro’s"), RetrievalText.terms("elektros"))
    }

    func testSloppyQuestionUsesSynonymsAtHalfWeight() {
        let q = PageIndex.queryTerms(question: "can my guys walk there")
        XCTAssertEqual(q["walk"], 1)
        XCTAssertEqual(q[RetrievalText.stem("move")], 0.5)
        XCTAssertEqual(q[RetrievalText.stem("warrior")], 0.5)
    }
}

final class PageIndexTests: XCTestCase {
    let pages = [
        "Setup: shuffle the cards and give each player a board.",                       // 1
        "Turn order: players take turns clockwise. Build one plant per turn.",           // 2
        "End of turn: discard all unused energy. Energy returns to the supply.",         // 3
        "Battery: a player who owns a Battery keeps up to 2 unused energy.",              // 4
        "Scoring: every 3 energy spent on a contract scores 1 victory point.",           // 5
        "Credits and index.",                                                            // 6
        "Variant rules for two players.",                                                // 7
        "Glossary of terms.",                                                            // 8
    ]

    func testRanksTheDefiningPageFirst() {
        let idx = PageIndex(pageTexts: pages)
        let s = idx.scores(question: "Do I keep my unused energy with a battery?")
        XCTAssertEqual(s.indices.max { s[$0] < s[$1] }.map { $0 + 1 }, 4)
        XCTAssertEqual(idx.scores(question: "zebra unicorn").filter { $0 > 0 }.count, 0)
    }

    func testHeadingTermsBoostTheDefiningPage() {
        let texts = ["Combat: when you move warriors into a clearing, battle may start.",
                     "Warriors move along paths. To move you must rule the origin or destination."]
        let q = "when can my warriors move"
        let plain = PageIndex(pageTexts: texts).scores(question: q)
        let boosted = PageIndex(pageTexts: texts, headings: ["Combat", "Moving Around the Map"]).scores(question: q)
        XCTAssertGreaterThan(boosted[1] - boosted[0], plain[1] - plain[0])
    }

    func testSelectTopKNeighboursAndPins() {
        let idx = PageIndex(pageTexts: pages)
        let o = PageSelectionOptions(topK: 1, neighbors: 1, fullIfCoverage: 1.1)
        let sel = idx.select(question: "battery keeps unused energy", options: o)
        XCTAssertFalse(sel.isFullDocument)
        XCTAssertEqual(sel.pages, [3, 4, 5])
        XCTAssertEqual(sel.ranked.first, 4)
        // Pages the conversation already cited are always sent.
        let pinned = idx.select(question: "battery keeps unused energy", pinned: [1], options: o)
        XCTAssertEqual(pinned.pages, [1, 3, 4, 5])
        XCTAssertEqual(pinned.pinned, [1])
    }

    func testFollowUpUsesEarlierQuestionText() {
        let idx = PageIndex(pageTexts: pages)
        let o = PageSelectionOptions(topK: 1, neighbors: 0, fullIfCoverage: 1.1)
        let sel = idx.select(question: "and with two of them?", history: ["what does a battery keep?"], options: o)
        XCTAssertEqual(sel.pages, [4])
    }

    func testFallsBackToFullDocument() {
        let idx = PageIndex(pageTexts: pages)
        XCTAssertTrue(idx.select(question: "zebra", options: PageSelectionOptions()).isFullDocument)
        let wide = idx.select(question: "battery energy", options: PageSelectionOptions(topK: 8, neighbors: 1, fullIfCoverage: 0.5))
        XCTAssertTrue(wide.isFullDocument)
        XCTAssertEqual(wide.pages, Array(1...8))
        let flat = idx.select(question: "battery", options: PageSelectionOptions(minConfidence: 1.01))
        XCTAssertTrue(flat.isFullDocument)
        XCTAssertNotNil(flat.reason)
    }
}

final class PageMappingTests: XCTestCase {
    let sel = PageSelection(pages: [3, 4, 9], pageCount: 12)

    func testExcerptPositionToOriginal() {
        XCTAssertEqual(sel.originalPage(excerptPage: 1), 3)
        XCTAssertEqual(sel.originalPage(excerptPage: 3), 9)
        XCTAssertNil(sel.originalPage(excerptPage: 4))
    }

    func testModelPagesResolveToOriginal() {
        XCTAssertEqual(sel.resolveModelPage(9), 9)   // asked for: original numbers
        XCTAssertEqual(sel.resolveModelPage(2), 4)   // counted excerpt pages instead
        XCTAssertEqual(sel.resolveModelPage(11), 11) // neither: leave it to the matcher
        XCTAssertEqual(PageSelection.full(pageCount: 12).resolveModelPage(2), 2)
        let a = Answer(restatedQuestion: "", verdict: "", confidence: .stated,
                       steps: [Step(text: "", evidence: [Evidence(page: 1, quote: "x"), Evidence(page: 9, quote: "y")])])
        XCTAssertEqual(sel.remap(a).steps[0].evidence.map(\.page), [3, 9])
    }

    func testNoteListsOriginalPages() {
        let n = sel.excerptNote(title: "Game")
        XCTAssertTrue(n.contains("rulebook pages 3, 4, 9"))
        XCTAssertTrue(n.contains("excerpt page 2 = rulebook page 4"))
    }
}

final class ExcerptTests: XCTestCase {
    static let url: URL = {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("ackshually-excerpt-\(UUID()).pdf")
        try! FixtureRulebook.write(to: u)
        return u
    }()

    func testExcerptPDFKeepsSelectedPagesInOrder() throws {
        let book = try XCTUnwrap(RulebookIndex(url: Self.url))
        let sel = book.selection(pages: [4, 2])
        XCTAssertEqual(sel.pages, [2, 4])
        let data = try XCTUnwrap(book.excerptPDF(sel))
        let out = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(out.pageCount, 2)
        XCTAssertTrue(out.page(at: 0)?.string?.contains("Turn order") ?? false)
        XCTAssertTrue(out.page(at: 1)?.string?.contains("Battery") ?? false)
        let text = book.excerptText(sel, title: "Fixture")
        XCTAssertTrue(text.contains("=== Rulebook page 4 ==="))
        XCTAssertFalse(text.contains("=== Rulebook page 3 ==="))
    }

    func testMisnumberedEvidenceIsCorrectedByQuote() throws {
        let book = try XCTUnwrap(RulebookIndex(url: Self.url))
        let sel = book.selection(pages: [2, 4])
        // Model says page 2 (in the selection) but the quote is on page 4: off-by-one numbering.
        let e = Evidence(page: 2, quote: "keeps up to 2 unused energy")
        XCTAssertEqual(book.resolvePage(e, in: sel), 4)
        // Quote really on the named page: kept.
        XCTAssertEqual(book.resolvePage(Evidence(page: 2, quote: "Players take turns in clockwise order"), in: sel), 2)
        // Quote nowhere / empty: keep the (mapped) named page.
        XCTAssertEqual(book.resolvePage(Evidence(page: 2, quote: "zebra unicorn rainbow"), in: sel), 2)
        XCTAssertEqual(book.resolvePage(Evidence(page: 1, quote: ""), in: sel), 2)
        // Citations: excerpt positions.
        XCTAssertEqual(book.resolvePage(Evidence(page: 2, quote: "keeps up to 2 unused energy"), in: sel, excerptPositions: true), 4)
    }

    func testRetrievalOnFixture() throws {
        let book = try XCTUnwrap(RulebookIndex(url: Self.url))
        let sel = book.select(question: "Does my battery keep unused energy?",
                              options: PageSelectionOptions(topK: 1, neighbors: 0, fullIfCoverage: 1.1))
        XCTAssertEqual(sel.pages, [4])
    }

    func testDefaultRequestIsUnchangedAndExcerptRequestCarriesNote() throws {
        let pdf = try Data(contentsOf: Self.url)
        let p = ClaudeProvider(config: ClaudeConfig(apiKey: "x"))
        let full = AnswerRequest(pdf: pdf, documentTitle: "T", question: "Q")
        XCTAssertEqual(full.pageSelection, .fullDocument)
        XCTAssertEqual(p.requestBody(for: full).serialized(), p.requestBody(for: full, excerpt: nil).serialized())
        XCTAssertFalse(p.requestBody(for: full).serialized().contains("EXCERPT"))

        var r = full
        r.pageSelection = .pages([2, 4], representation: .text)
        let prep = p.prepareExcerpt(r)
        let ex = try XCTUnwrap(prep.excerpt)
        XCTAssertEqual(ex.selection.pages, [2, 4])
        let body = p.requestBody(for: r, excerpt: ex).serialized()
        XCTAssertTrue(body.contains("EXCERPT"))
        XCTAssertTrue(body.contains("Rulebook page 4"))
        XCTAssertFalse(body.contains("application/pdf"))
    }
}

/// Serves canned SSE: the excerpt request answers not_covered, the full-PDF request answers stated.
final class MockAPI: URLProtocol {
    nonisolated(unsafe) static var requests: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = Data()
        if let s = request.httpBodyStream {
            s.open()
            var buf = [UInt8](repeating: 0, count: 65536)
            while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; body.append(buf, count: n) }
            s.close()
        }
        let text = String(decoding: body, as: UTF8.self)
        let excerpt = text.contains("EXCERPT")
        Self.requests.append(excerpt ? "excerpt" : "full")
        let conf = excerpt ? "not_covered" : "stated"
        let page = excerpt ? 1 : 4
        let json = #"{"restated_question":"Q","verdict":"V","confidence":"\#(conf)","branches":[],"assumptions":[],"steps":[{"text":"t","evidence":[{"page":\#(page),"quote":"keeps up to 2 unused energy","box":null}]}],"needs_web":false}"#
        let esc = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let sse = [
            #"{"type":"message_start","message":{"model":"m","usage":{"input_tokens":100,"output_tokens":1}}}"#,
            #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\#(esc)"}}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":50}}"#,
        ].map { "data: \($0)\n\n" }.joined()
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(sse.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class SelectionProviderTests: XCTestCase {
    func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [MockAPI.self]
        return URLSession(configuration: c)
    }

    func collect(_ p: ClaudeProvider, _ r: AnswerRequest) async throws -> [AnswerEvent] {
        var out: [AnswerEvent] = []
        for try await e in p.answer(r) { out.append(e) }
        return out
    }

    func testNotCoveredOnExcerptFallsBackToFullPDFAndHidesDiscardedAttempt() async throws {
        MockAPI.requests = []
        let pdf = try Data(contentsOf: ExcerptTests.url)
        let p = ClaudeProvider(config: ClaudeConfig(apiKey: "x", useFallbacks: false), session: session())
        let r = AnswerRequest(pdf: pdf, documentTitle: "T", question: "Does my battery keep unused energy?",
                              pageSelection: .automatic(PageSelectionOptions(topK: 1, neighbors: 0, fullIfCoverage: 1.1)))
        let events = try await collect(p, r)
        XCTAssertEqual(MockAPI.requests, ["excerpt", "full"])
        let confidences = events.compactMap { if case .confidence(let c) = $0 { return c } else { return nil } }
        XCTAssertEqual(confidences, [.stated])
        XCTAssertEqual(events.filter { if case .firstToken = $0 { return true } else { return false } }.count, 1)
        guard case .completed(let res) = events.last else { return XCTFail() }
        XCTAssertEqual(res.answer?.confidence, .stated)
        XCTAssertEqual(res.retrieval?.fellBackToFullDocument, true)
        XCTAssertEqual(res.retrieval?.selection.pages, [4])
        XCTAssertEqual(res.usage.inputTokens, 200)  // both attempts are billed
        XCTAssertEqual(res.retrieval?.discardedUsage?.inputTokens, 100)
    }

    func testExcerptAnswerPagesAreMappedBack() async throws {
        MockAPI.requests = []
        let pdf = try Data(contentsOf: ExcerptTests.url)
        let p = ClaudeProvider(config: ClaudeConfig(apiKey: "x", useFallbacks: false), session: session())
        // No fallback: the excerpt answer (which cites excerpt page 1) is kept and mapped to page 4.
        let r = AnswerRequest(pdf: pdf, documentTitle: "T", question: "Does my battery keep unused energy?",
                              pageSelection: .automatic(PageSelectionOptions(topK: 1, neighbors: 0, fullIfCoverage: 1.1,
                                                                             fallbackOnNotCovered: false)))
        let events = try await collect(p, r)
        XCTAssertEqual(MockAPI.requests, ["excerpt"])
        let evPages = events.compactMap { if case .evidence(_, _, let e) = $0 { return e.page } else { return nil } }
        XCTAssertEqual(evPages, [4])
        guard case .completed(let res) = events.last else { return XCTFail() }
        XCTAssertEqual(res.answer?.steps.first?.evidence.first?.page, 4)
        XCTAssertEqual(res.retrieval?.remappedPages, 1)
    }
}
