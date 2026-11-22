import XCTest
import CoreGraphics
import CoreText
import PDFKit
@testable import AckshuallyCore

/// Layout-tolerant matching (spec §4 step 2) on generated PDFs whose text layer interleaves two
/// columns, like Root p.15 (main column + sidebar). Never rulebook pages.
final class FragmentMatchTests: XCTestCase {
    /// Page 1: a main column and a sidebar 10 pt to its right, each sidebar line 4 pt lower than the
    /// main line beside it. PDFKit reads them as one line each, so the text layer interleaves them:
    /// "…sympathetic␣Sidebar: the keep token\nclearing. Remove all enemy pieces there and place␣Only you…".
    static let main = [
        "Revolt: spend two supporters matching a sympathetic",
        "clearing. Remove all enemy pieces there and place",
        "the matching base. Then place warriors there equal",
        "to the number of sympathetic clearings you rule.",
    ]
    static let sidebar = [
        "Sidebar: the keep token",
        "Only you can place pieces",
        "in the clearing with the",
        "keep token at any time.",
    ]
    /// Page 2: the two halves of one sentence far apart (top left, bottom right), short enough
    /// (< 30 characters each) that neither can be a partial match on its own.
    static let scatteredTop = "Each player draws three cards"
    static let scatteredBottom = "and discards one face down"
    /// Page 3: common words all over, never the quote.
    static let common = [
        "At the end of the round, every player scores.",
        "On your turn you may move once.",
        "You must discard all of the tokens in the supply.",
        "Cards of your color are yours to keep.",
    ]

    static let pdf: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ackshually-interleaved-\(UUID()).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = CGContext(consumer: CGDataConsumer(url: url as CFURL)!, mediaBox: &box, nil)!
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        func draw(_ s: String, _ x: CGFloat, _ y: CGFloat) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.init(kCTFontAttributeName as String): font]))
            ctx.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, ctx)
        }
        ctx.beginPDFPage(nil)
        for i in main.indices {
            draw(main[i], 60, 700 - CGFloat(i) * 16)
            draw(sidebar[i], 340, 700 - CGFloat(i) * 16 - 4)
        }
        ctx.endPDFPage()
        ctx.beginPDFPage(nil)
        draw(scatteredTop, 60, 720)
        draw("Setup takes about five minutes for new players.", 60, 400)
        draw(scatteredBottom, 380, 80)
        ctx.endPDFPage()
        ctx.beginPDFPage(nil)
        for (i, l) in common.enumerated() { draw(l, 60, 700 - CGFloat(i) * 40) }
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }()

    private func matcher() throws -> QuoteMatcher {
        try XCTUnwrap(QuoteMatcher(url: Self.pdf))
    }

    func testTextLayerIsInterleaved() throws {
        // Precondition for the tests below: the quote is not one run in the text layer.
        let text = try XCTUnwrap(matcher().document.page(at: 0)?.string)
        XCTAssertTrue(text.contains("place Only you can place pieces"), text)
    }

    func testInterleavedQuoteMatchesThroughFragments() throws {
        let m = try matcher()
        let quote = "Remove all enemy pieces there and place the matching base. Then place warriors there equal to the number"
        guard case .matched(let q) = m.match(quote: quote, page: 1) else { return XCTFail("\(m.match(quote: quote, page: 1).label)") }
        XCTAssertEqual(q.layout, .fragments)
        XCTAssertGreaterThanOrEqual(q.fragments.count, 2)
        XCTAssertGreaterThanOrEqual(q.coverage, 0.85)
        XCTAssertNotNil(q.layoutScore)
        XCTAssertTrue(m.match(quote: quote, page: 1).label.hasPrefix("matched ("))
        // Every rect sits in the main column (x 60–330 pt of 612), on lines 2–4 (y from the top ≈ 92–146 pt of 792).
        XCTAssertFalse(q.rects.isEmpty)
        for r in q.rects {
            XCTAssertGreaterThan(r.x, 0.08, "\(r)")
            XCTAssertLessThan(r.x + r.w, 0.56, "sidebar boxed: \(r)")
            XCTAssertGreaterThan(r.y, 0.10, "\(r)")
            XCTAssertLessThan(r.y + r.h, 0.20, "\(r)")
        }
        XCTAssertEqual(q.rects.count, q.fragments.reduce(0) { $0 + $1.rects.count })
        XCTAssertFalse(q.matchedText.contains("Only you"), q.matchedText)
    }

    func testScatteredFragmentsAreRejectedByGeometry() throws {
        let m = try matcher()
        let quote = "\(Self.scatteredTop) \(Self.scatteredBottom)."
        // Both halves are on the page as long fragments…
        let text = try XCTUnwrap(m.normalized(page: 2))
        let q = NormalizedText(quote)
        let found = FragmentMatcher.fragments(q.chars, wordStarts: FragmentMatcher.wordStarts(q), in: text.chars)
        XCTAssertEqual(found.count, 2)
        // …but not as one block, so no match.
        let outcome = m.match(quote: quote, page: 2)
        guard case .notMatched = outcome else { return XCTFail("scattered quote matched: \(outcome.label)") }
    }

    func testLayoutCheckSplitsDistantFragments() {
        let page = CGSize(width: 612, height: 792)
        let line1 = [CGRect(x: 60, y: 80, width: 250, height: 12)]
        let line2 = [CGRect(x: 60, y: 96, width: 200, height: 12)]
        let far = [CGRect(x: 380, y: 700, width: 180, height: 12)]
        XCTAssertEqual(LayoutCheck.blocks([line1, line2], page: page).map(\.fragments), [0..<2])
        XCTAssertEqual(LayoutCheck.blocks([line1, far], page: page).map(\.fragments), [0..<1, 1..<2])
        // A wrap from the end of one line to the start of the next stays one block.
        let end = [CGRect(x: 220, y: 80, width: 90, height: 12)]
        let start = [CGRect(x: 60, y: 96, width: 70, height: 12)]
        XCTAssertEqual(LayoutCheck.blocks([end, start], page: page).map(\.fragments), [0..<2])
        // The next fragment above the previous one (another column's top) is a new block.
        XCTAssertEqual(LayoutCheck.blocks([line2, line1], page: page).count, 2)
    }

    func testCommonWordsDoNotAssembleAQuote() throws {
        let m = try matcher()
        for quote in [
            "At the end of your turn you must discard all of your cards.",
            "You may move your tokens at the end of the round.",
            "Discard all cards.",
        ] {
            let outcome = m.match(quote: quote, page: 3)
            guard case .notMatched = outcome else { XCTFail("“\(quote)” → \(outcome.label)"); continue }
        }
    }

    func testPartialQuoteIsHighlightedAsPartial() throws {
        let m = try matcher()
        let quote = "Revolt: spend two supporters matching a sympathetic clearing, then gain three victory points and draw a card."
        let outcome = m.match(quote: quote, page: 1)
        guard case .matched(let q) = outcome else { return XCTFail(outcome.label) }
        XCTAssertEqual(q.layout, .partial)
        XCTAssertGreaterThanOrEqual(q.coverage, 0.3)
        XCTAssertLessThan(q.coverage, 0.85)
        XCTAssertTrue(outcome.label.hasPrefix("partial match"), outcome.label)
        XCTAssertFalse(q.rects.isEmpty)
        for r in q.rects { XCTAssertLessThan(r.x + r.w, 0.56, "\(r)"); XCTAssertLessThan(r.y, 0.15, "\(r)") }
    }

    func testPartialOnlyOnTheClaimedPage() throws {
        let m = try matcher()
        let quote = "Revolt: spend two supporters matching a sympathetic clearing, then gain three victory points and draw a card."
        guard case .notMatched = m.match(quote: quote, page: 2) else { return XCTFail("partial match taken from a neighbouring page") }
    }

    func testContinuousMatchesAreUnchanged() throws {
        let m = try matcher()
        for (quote, page) in [("Sidebar: the keep token", 1), ("Setup takes about five minutes for new players.", 2)] {
            guard case .matched(let q) = m.match(quote: quote, page: page) else { XCTFail(quote); continue }
            XCTAssertEqual(q.layout, .continuous)
            XCTAssertEqual(q.coverage, 1)
            XCTAssertTrue(q.fragments.isEmpty)
            XCTAssertEqual(q.errorRate, 0)
            XCTAssertEqual(m.match(quote: quote, page: page).label, "matched")
        }
        // With layout tolerance off, the interleaved quote is a plain miss (the old behaviour).
        let off = try matcher()
        off.layoutTolerant = false
        guard case .notMatched = off.match(quote: "Remove all enemy pieces there and place the matching base. Then place warriors there equal to the number", page: 1)
        else { return XCTFail("continuous-only matcher matched an interleaved quote") }
    }

    func testFragmentsAreWholeWords() {
        // "…extra actions" + "b" of "by" must not swallow the "B" of "Battle" on the page.
        let q = NormalizedText("you may take any number of extra actions by spending one bird card")
        let t = NormalizedText("you may take any number of extra actions\n» Battle: Initiate a battle.\nby spending one bird card")
        let f = FragmentMatcher.fragments(q.chars, wordStarts: FragmentMatcher.wordStarts(q), in: t.chars)
        XCTAssertEqual(f.count, 2)
        let first = t.original as NSString
        XCTAssertEqual(first.substring(with: t.originalRange(f[0].text)), "you may take any number of extra actions")
        XCTAssertEqual(first.substring(with: t.originalRange(f[1].text)), "by spending one bird card")
    }

    func testOldRecordsDecodeAsContinuous() throws {
        let json = #"{"page":3,"errorRate":0,"rects":[],"matchedText":"x"}"#
        let q = try JSONDecoder().decode(QuoteMatch.self, from: Data(json.utf8))
        XCTAssertEqual(q.layout, .continuous)
        XCTAssertEqual(q.coverage, 1)
    }
}
