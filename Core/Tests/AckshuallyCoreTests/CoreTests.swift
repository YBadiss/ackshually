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

    /// Step titles and per-branch steps (contract v2) stream and decode; old answers still decode.
    func testStepTitlesAndBranchSteps() throws {
        let v2 = """
        {"restated_question":"q","verdict":"Keep 2.","confidence":"stated",\
        "branches":[{"condition":"No Battery","verdict":"Discard all 3.","steps":[{"title":"General rule","text":"All goes.",\
        "evidence":[{"page":3,"quote":"discard all unused energy","box":null}]}]}],"assumptions":[],\
        "steps":[{"title":"Battery exception","text":"Keeps 2.","evidence":[{"page":4,"quote":"  ","box":null}]}],"needs_web":false}
        """
        var a = JSONAnswerAssembler()
        var branch: Branch?
        var step: Step?
        for ch in v2 {
            for e in a.feed(String(ch)) {
                if case .branch(let b) = e { branch = b }
                if case .step(_, let s) = e { step = s }
            }
        }
        XCTAssertEqual(branch?.steps.first?.title, "General rule")
        XCTAssertEqual(branch?.steps.first?.evidence.first?.page, 3)
        XCTAssertEqual(step?.title, "Battery exception")
        XCTAssertNil(step?.evidence.first?.quote, "blank quotes are normalized to nil")
        let ans = try a.finish().get()
        XCTAssertEqual(ans.branches.first?.steps.count, 1)
        XCTAssertEqual(ans.steps.first?.title, "Battery exception")

        // v1 (no titles, no branch steps) still decodes, and an empty title reads as none.
        var old = JSONAnswerAssembler()
        _ = old.feed(sample)
        let o = try old.finish().get()
        XCTAssertNil(o.steps.first?.title)
        XCTAssertEqual(o.branches.first?.steps, [])
        let blank = try JSONDecoder().decode(Step.self, from: Data(#"{"title":" ","text":"t"}"#.utf8))
        XCTAssertNil(blank.title)
    }

    /// Owner feedback 2026-11-21: verdicts ran to 5 bold lines and the last step repeated the verdict.
    func testPromptLimitsVerdictAndForbidsRepeatingIt() {
        XCTAssertTrue(Prompts.common.contains("at most 12 words"))
        XCTAssertTrue(Prompts.common.contains("never restate"))
        XCTAssertTrue(Prompts.jsonSystem.contains("Never title a step \"Result\""))
        // Schema field order (= streaming order) is unchanged.
        let order = ["restated_question", "verdict", "confidence", "steps", "branches", "assumptions", "needs_web"]
        let tail = Prompts.jsonSystem.components(separatedBy: "keys in this order:").last ?? ""
        let positions = order.compactMap { tail.range(of: $0)?.lowerBound }
        XCTAssertEqual(positions.count, order.count)
        XCTAssertEqual(positions, positions.sorted())
    }

    func testSchemaHasTitlesAndBranchSteps() {
        let body = ClaudeProvider(config: ClaudeConfig(apiKey: "x"))
            .requestBody(for: AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q")).serialized()
        XCTAssertTrue(body.contains(#""required":["title","text","evidence"]"#))
        XCTAssertTrue(body.contains(#""required":["condition","verdict","steps"]"#))
    }

    func testCredentialHeaders() {
        let direct = ClaudeProvider(config: ClaudeConfig(apiKey: "sk-x"))
            .urlRequest(for: AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q"))
        XCTAssertEqual(direct.value(forHTTPHeaderField: "x-api-key"), "sk-x")
        XCTAssertNil(direct.value(forHTTPHeaderField: "authorization"))

        let server = URL(string: "https://ackshually.badyass.xyz")!
        let proxied = ClaudeProvider(config: ClaudeConfig(credential: .appToken("ack_t"), baseURL: server))
            .urlRequest(for: AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q"))
        XCTAssertEqual(proxied.url?.absoluteString, "https://ackshually.badyass.xyz/v1/messages")
        XCTAssertEqual(proxied.value(forHTTPHeaderField: "authorization"), "Bearer ack_t")
        XCTAssertNil(proxied.value(forHTTPHeaderField: "x-api-key"))
    }

    /// The server (Server/src/validate.ts) refuses any top-level field it doesn't know. If this fails, add the
    /// new field there too, or the app breaks as soon as it talks to the server.
    func testRequestFieldsAreAllowedByServer() throws {
        let serverAllows: Set<String> = ["model", "max_tokens", "stream", "system", "output_config", "cache_control",
                                         "messages", "fallbacks"]
        for mode in [EvidenceMode.json, .citations] {
            let body = ClaudeProvider(config: ClaudeConfig(apiKey: "x", mode: mode))
                .requestBody(for: AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q")).data
            let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any]).keys)
            XCTAssertTrue(keys.isSubset(of: serverAllows), "not allowed by the server: \(keys.subtracting(serverAllows))")
        }
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
        XCTAssertTrue(body.contains("\"cache_control\":{\"type\":\"ephemeral\",\"ttl\":\"1h\"}"))
        XCTAssertFalse(body.contains("\"cache_control\":{\"type\":\"ephemeral\"}"), "all markers share the 1h TTL")
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

    /// Regression (Azul p.3, owner's screenshots): boxes must sit on the quote, not several words
    /// later. The fixture's text starts at x = 72 pt of 612, so a quote that starts a paragraph
    /// starts at the left margin, and a one-line quote gets one rect.
    func testRectsSitOnTheQuote() {
        let m = matcher.match(quote: "Energy may not be traded between players", page: 3)
        guard case .matched(let q) = m else { return XCTFail(m.label) }
        XCTAssertEqual(q.rects.count, 1)
        XCTAssertEqual(q.rects[0].x, 72.0 / 612, accuracy: 0.01)
        XCTAssertGreaterThan(q.geometryScore ?? 0, GlyphLocator.minScore)
        let later = matcher.match(quote: "Scoring: every 3 energy spent on a contract", page: 3).match
        XCTAssertEqual(later?.rects.first?.x ?? 0, 72.0 / 612, accuracy: 0.01)
        XCTAssertGreaterThan(later?.rects.first?.y ?? 0, q.rects[0].y)
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

    func testOneHourCacheWriteCost() {
        // 10k tokens written with 1h TTL on Sonnet 5.5: 10_000 * $2 * 2 / 1M = $0.04
        let u = TokenUsage(cacheCreationInputTokens: 10_000, cacheCreation1hInputTokens: 10_000)
        XCTAssertEqual(ModelPricing.cost(model: "claude-sonnet-5-5", usage: u)!, 0.04, accuracy: 1e-9)
        let five = TokenUsage(cacheCreationInputTokens: 10_000)
        XCTAssertEqual(ModelPricing.cost(model: "claude-sonnet-5-5", usage: five)!, 0.025, accuracy: 1e-9)
    }
}
