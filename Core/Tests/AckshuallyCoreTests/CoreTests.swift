import XCTest
import PDFKit
@testable import AckshuallyCore

final class IncrementalJSONTests: XCTestCase {
    let sample = """
    {"restated_question":"You have 3 energy and a Battery at end of turn.","verdict":"Keep 2, discard 1.",\
    "confidence":"stated","branches":[{"condition":"Without a Battery","verdict":"Discard all 3."}],\
    "assumptions":[],"steps":[{"text":"General rule.","evidence":[{"page":3,"quote":"discard all unused energy","box":null}]},\
    {"text":"Battery exception.","evidence":[{"page":4,"quote":"keeps up to 2 unused energy","box":null}]}],"needs_web":false}
    """

    /// Feed one char at a time; events must arrive in contract order and as soon as each value closes.
    func testStreamingOrderCharByChar() {
        var a = JSONAnswerAssembler()
        var log: [String] = []
        for ch in sample {
            for e in a.feed(String(ch)) {
                switch e {
                case .restatedQuestion: log.append("restated")
                case .verdict(let v): log.append("verdict:\(v)")
                case .confidence(let c): log.append("conf:\(c.rawValue)")
                case .branch: log.append("branch")
                case .evidence(let s, let i, let ev): log.append("ev\(s).\(i):p\(ev.page)")
                case .step(let i, _): log.append("step\(i)")
                default: break
                }
            }
        }
        XCTAssertEqual(log, ["restated", "verdict:Keep 2, discard 1.", "conf:stated", "branch",
                             "ev0.0:p3", "step0", "ev1.0:p4", "step1"])
        let ans = try! a.finish().get()
        XCTAssertEqual(ans.steps.count, 2)
        XCTAssertEqual(ans.branches.first?.verdict, "Discard all 3.")
        XCTAssertFalse(ans.needsWeb)
    }

    func testEscapesAndFenceNoise() {
        var a = JSONAnswerAssembler()
        _ = a.feed("```json\n{\"restated_question\":\"He said \\\"no\\\" {really}\",\"verdict\":\"x\",\"confidence\":\"inferred\",")
        _ = a.feed("\"branches\":[],\"assumptions\":[\"a\"],\"steps\":[],\"needs_web\":true}\n```")
        let ans = try! a.finish().get()
        XCTAssertEqual(ans.restatedQuestion, "He said \"no\" {really}")
        XCTAssertEqual(ans.confidence, .inferred)
    }

    func testTruncatedIsFailure() {
        var a = JSONAnswerAssembler()
        _ = a.feed(String(sample.prefix(120)))
        if case .success = a.finish() { XCTFail("truncated JSON must fail") }
    }

    func testRequestBodyKeepsSchemaOrderAndCaching() {
        let p = ClaudeProvider(config: ClaudeConfig(apiKey: "x"))
        let body = p.requestBody(for: AnswerRequest(pdf: Data([1, 2, 3]), documentTitle: "T", question: "Q2",
                                                    history: [Turn(question: "Q1", answer: nil, rawAssistantText: "{}")])).serialized()
        let r = body.range(of: "\"restated_question\"")!.lowerBound
        let v = body.range(of: "\"verdict\":{")!.lowerBound
        let s = body.range(of: "\"steps\":{")!.lowerBound
        XCTAssertTrue(r < v && v < s)
        XCTAssertTrue(body.contains("\"cache_control\":{\"type\":\"ephemeral\"}"))
        XCTAssertTrue(body.contains("\"fallbacks\":\"default\""))
        XCTAssertTrue(body.contains("{\"role\":\"assistant\",\"content\":\"{}\"},{\"role\":\"user\",\"content\":\"Q2\"}"))
        // Deterministic → stable cache prefix.
        XCTAssertEqual(body, p.requestBody(for: AnswerRequest(pdf: Data([1, 2, 3]), documentTitle: "T", question: "Q2",
                                                              history: [Turn(question: "Q1", answer: nil, rawAssistantText: "{}")])).serialized())
    }
}

final class SSEParserTests: XCTestCase {
    func sse(_ objs: [String]) -> [String] { objs.map { "data: " + $0 } }

    func testJSONModeStream() throws {
        var p = SSEAnswerParser(mode: .json, model: "claude-opus-5-5")
        let lines = sse([
            #"{"type":"message_start","message":{"model":"claude-opus-5-5","usage":{"input_tokens":12,"cache_read_input_tokens":30000,"cache_creation_input_tokens":0,"output_tokens":1}}}"#,
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":""}}"#,
            #"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"{\"restated_question\":\"Q\",\"verdict\":\"V\","}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"\"confidence\":\"stated\",\"branches\":[],\"assumptions\":[],\"steps\":[],\"needs_web\":false}"}}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":55}}"#,
        ])
        var events: [AnswerEvent] = []
        for l in lines { events += try p.consume(line: l) }
        events += p.finish()
        guard case .firstToken = events.first else { return XCTFail() }
        guard case .completed(let r) = events.last else { return XCTFail() }
        XCTAssertEqual(r.answer?.verdict, "V")
        XCTAssertEqual(r.usage, TokenUsage(inputTokens: 12, outputTokens: 55, cacheCreationInputTokens: 0, cacheReadInputTokens: 30000))
        XCTAssertNil(r.parseError)
    }

    func testCitationsModeStream() throws {
        var p = SSEAnswerParser(mode: .citations, model: "m")
        let lines = sse([
            #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"QUESTION: 3 energy + Battery\nVERDICT: Keep 2.\nCONFIDENCE: stated\nSTEP: General rule: "}}"#,
            #"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"unused energy is discarded"}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"citations_delta","citation":{"type":"page_location","cited_text":"Clean-up: at the end of your turn you must discard all unused energy. ","document_index":0,"start_page_number":3,"end_page_number":4}}}"#,
            #"{"type":"content_block_start","index":2,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":2,"delta":{"type":"text_delta","text":"\nSTEP: Battery keeps 2.\nNEEDS_WEB: no"}}"#,
        ])
        var events: [AnswerEvent] = []
        for l in lines { events += try p.consume(line: l) }
        events += p.finish()
        guard case .completed(let r) = events.last, let a = r.answer else { return XCTFail() }
        XCTAssertEqual(a.restatedQuestion, "3 energy + Battery")
        XCTAssertEqual(a.steps.count, 2)
        XCTAssertEqual(a.steps[0].evidence.first?.page, 3)
        XCTAssertEqual(a.steps[0].text, "General rule: unused energy is discarded")
        XCTAssertTrue(a.steps[1].evidence.isEmpty)
        XCTAssertFalse(a.needsWeb)
    }
}

final class MatcherTests: XCTestCase {
    static let url: URL = {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("ackshually-fixture-\(UUID()).pdf")
        try! FixtureRulebook.write(to: u)
        return u
    }()

    var matcher: QuoteMatcher { QuoteMatcher(url: Self.url)! }

    func testExact() {
        let m = matcher.match(quote: "you must discard all unused energy", page: 3)
        guard case .matched(let q) = m else { return XCTFail(m.label) }
        XCTAssertEqual(q.errorRate, 0)
        XCTAssertFalse(q.rects.isEmpty)
        for r in q.rects { XCTAssertTrue(r.w > 0.05 && r.h > 0.005 && r.x >= 0 && r.y >= 0 && r.x + r.w <= 1) }
        // Text is drawn in the top half of the page.
        XCTAssertLessThan(q.rects[0].y, 0.5)
    }

    func testWhitespacePunctuationCaseAndLineBreaks() {
        // Spans a line break in the narrow column; different case/punctuation/quotes.
        let m = matcher.match(quote: "a player who owns a Battery — keeps up to 2 unused energy, instead of discarding them", page: 4)
        guard case .matched = m else { return XCTFail(m.label) }
    }

    func testMinorDifferences() {
        // Paraphrase-level typos (2 chars off) still match; the model often drops/changes a word.
        let m = matcher.match(quote: "keeps up to two unused energy instead of discarding them", page: 4)
        guard case .matched(let q) = m else { return XCTFail(m.label) }
        XCTAssertGreaterThan(q.errorRate, 0)
    }

    func testWrongPageIsReported() {
        let m = matcher.match(quote: "discard all unused energy", page: 2)
        guard case .matchedOtherPage(let q, 2) = m else { return XCTFail(m.label) }
        XCTAssertEqual(q.page, 3)
    }

    func testNotInBook() {
        let m = matcher.match(quote: "players may trade energy freely during the auction", page: 3)
        guard case .notMatched = m else { return XCTFail(m.label) }
    }

    func testLigatureAndHyphenNormalization() {
        let a = NormalizedText("Eﬃcient re-\nroll ﬁnal")
        let b = NormalizedText("efficient reroll final")
        XCTAssertEqual(a.chars, b.chars)
    }

    func testBoxChecks() {
        XCTAssertEqual(QuoteMatcher.check(box: .init(x: 0.15, y: 0.55, w: 0.7, h: 0.3)), .ok)
        XCTAssertEqual(QuoteMatcher.check(box: .init(x: 0.5, y: 0.5, w: 0.7, h: 0.3)), .outOfPage)
        XCTAssertEqual(QuoteMatcher.check(box: .init(x: 0.5, y: 0.5, w: 0.0, h: 0.3)), .degenerate)
        XCTAssertEqual(QuoteMatcher.check(box: .init(x: 0, y: 0, w: 1, h: 1)), .wholePage)
        let fig = FixtureRulebook.pages[3].figure!.box
        XCTAssertGreaterThan(fig.iou(.init(x: 0.18, y: 0.5, w: 0.7, h: 0.32)), 0.7)
    }
}
