import XCTest
import PDFKit
@testable import AckshuallyCore

/// Streams a canned SSE reply (or an error status) and records the request.
final class SorterStubAPI: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var reply = ""
    nonisolated(unsafe) static var seen: [Data] = []

    static func sse(text: String, stop: String = "end_turn") -> String {
        func event(_ o: [String: Any]) -> String {
            "data: " + String(decoding: try! JSONSerialization.data(withJSONObject: o), as: UTF8.self) + "\n\n"
        }
        let half = text.index(text.startIndex, offsetBy: text.count / 2)
        return event(["type": "message_start", "message": ["model": "claude-haiku-5-5"]])
            + event(["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]])
            + event(["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": String(text[..<half])]])
            + event(["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": String(text[half...])]])
            + event(["type": "message_delta", "delta": ["stop_reason": stop], "usage": ["output_tokens": 80]])
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
            Self.seen.append(data)
        } else {
            Self.seen.append(request.httpBody ?? Data())
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil,
                                   headerFields: ["content-type": Self.status == 200 ? "text/event-stream" : "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.reply.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class RulebookSorterTests: XCTestCase {
    let files = [
        RulebookSorter.File(fileName: "root-law.pdf", pdfTitle: "The Law of Root", pageCount: 40, text: "Law of Root"),
        RulebookSorter.File(fileName: "riverfolk.pdf", pdfTitle: nil, pageCount: 12, text: "The Riverfolk Expansion"),
        RulebookSorter.File(fileName: "azul.pdf", pdfTitle: "Azul", pageCount: 8, text: "Azul rules"),
        RulebookSorter.File(fileName: "score.pdf", pdfTitle: nil, pageCount: 1, text: "Score pad"),
    ]
    let games = [RulebookSorter.Game(id: "root-law-old.pdf", title: "Root", books: ["Learning to Play"])]

    func testParsesExistingNewSkippedAndCleansUp() throws {
        let reply = """
        ```json
        {"files":[
          {"index":1,"existing_game_id":"root-law-old.pdf","game_name":"Root","role":"core","title":" Law of Root ","reason":"rules reference","not_a_rulebook":false},
          {"index":2,"existing_game_id":"","game_name":"Root","role":"add_on","title":"Riverfolk","reason":"expansion","not_a_rulebook":false},
          {"index":2,"existing_game_id":"","game_name":"Other","role":"core","title":"Dup","reason":"","not_a_rulebook":false},
          {"index":3,"existing_game_id":"nope","game_name":"Azul","role":"core","title":"Rulebook","reason":"","not_a_rulebook":false},
          {"index":4,"existing_game_id":"","game_name":"Azul","role":"add_on","title":"Score Pad","reason":"score sheet","not_a_rulebook":true},
          {"index":9,"existing_game_id":"","game_name":"X","role":"core","title":"X","reason":"","not_a_rulebook":false}
        ]}
        ```
        """
        let s = try RulebookSorter.parse(reply, files: files, games: games)
        XCTAssertEqual(s.map(\.fileName), ["root-law.pdf", "riverfolk.pdf", "azul.pdf", "score.pdf"])
        XCTAssertEqual(s[0].target, .existing(id: "root-law-old.pdf"))
        XCTAssertEqual(s[0].title, "Law of Root")
        XCTAssertEqual(s[0].role, .core)
        XCTAssertEqual(s[1].target, .new(name: "Root"), "first entry for a file wins")
        XCTAssertEqual(s[1].role, .addOn)
        XCTAssertEqual(s[2].target, .new(name: "Azul"), "an unknown game id becomes a new game")
        XCTAssertTrue(s[3].notARulebook)
    }

    func testBadJSONThrows() {
        for bad in ["", "Sure! Here are the groups:", #"{"files":[{"index":"one"}]}"#, #"{"games":[]}"#, #"{"files":[{"index":1"#] {
            XCTAssertThrowsError(try RulebookSorter.parse(bad, files: files, games: games), bad) {
                guard case RulebookSorter.SortError.badReply = $0 else { return XCTFail("\($0)") }
            }
        }
    }

    func testEntryWithoutAGameIsDropped() throws {
        let s = try RulebookSorter.parse(#"{"files":[{"index":1,"existing_game_id":"","game_name":" ","role":"core","title":"T","reason":"","not_a_rulebook":false}]}"#,
                                         files: files, games: games)
        XCTAssertTrue(s.isEmpty)
    }

    /// The server's sort shape: Haiku, small max_tokens, text only (no document), streamed, structured output.
    func testRequestBodyShape() throws {
        let sorter = RulebookSorter(credential: .appToken("ack_t"), baseURL: URL(string: "https://server.test")!)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sorter.requestBody(files, games: games, preferredGameID: "root-law-old.pdf").data) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "claude-haiku-5-5")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertLessThanOrEqual(body["max_tokens"] as! Int, RulebookSorter.maxTokensCap)
        XCTAssertEqual((body["thinking"] as? [String: Any])?["type"] as? String, "disabled")
        let oc = try XCTUnwrap(body["output_config"] as? [String: Any])
        XCTAssertEqual((oc["format"] as? [String: Any])?["type"] as? String, "json_schema")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        let prompt = try XCTUnwrap(messages[0]["content"] as? String)
        XCTAssertTrue(prompt.contains(#"id "root-law-old.pdf": "Root""#))
        XCTAssertTrue(prompt.contains("prefer it"))
        XCTAssertTrue(prompt.contains("name: riverfolk.pdf"))
        XCTAssertFalse(body.description.contains("document"))
        let serverAllows: Set<String> = ["model", "max_tokens", "stream", "system", "thinking", "output_config", "messages"]
        XCTAssertTrue(Set(body.keys).isSubset(of: serverAllows), "keep Server/src/validate.ts's sort shape in sync")
        XCTAssertEqual(RulebookSorter.maxTokens(files: 100), RulebookSorter.maxTokensCap)
    }

    func testFileReadsFirstTwoPagesClipped() throws {
        let url = try FixtureRulebook.write(to: FileManager.default.temporaryDirectory.appending(path: "sorter-fixture.pdf"))
        let doc = try XCTUnwrap(PDFDocument(url: url))
        let f = try XCTUnwrap(RulebookSorter.File(fileName: "power-plant-rush.pdf", url: url))
        XCTAssertEqual(f.pageCount, doc.pageCount)
        XCTAssertFalse(f.text.isEmpty)
        XCTAssertLessThanOrEqual(f.text.count, RulebookSorter.File.textLimit)
        XCTAssertFalse(f.text.contains("\n"))
        let page3 = RulebookIndex.pageText(doc, at: 2).split(whereSeparator: \.isWhitespace).prefix(6).joined(separator: " ")
        if !page3.isEmpty, !RulebookIndex.pageText(doc, at: 0).contains(page3) { XCTAssertFalse(f.text.contains(page3)) }
        XCTAssertEqual(RulebookSorter.File.clip(String(repeating: "word  \n", count: 1000)).count, RulebookSorter.File.textLimit)
    }

    private func sorter() -> RulebookSorter {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [SorterStubAPI.self]
        return RulebookSorter(credential: .appToken("ack_t"), baseURL: URL(string: "https://server.test")!,
                              session: URLSession(configuration: c))
    }

    func testSortsThroughAStreamedReply() async throws {
        SorterStubAPI.status = 200
        SorterStubAPI.seen = []
        SorterStubAPI.reply = SorterStubAPI.sse(text: #"{"files":[{"index":1,"existing_game_id":"","game_name":"Azul","role":"core","title":"Azul","reason":"base rules","not_a_rulebook":false}]}"#)
        let s = try await sorter().sort([files[2]], games: [])
        XCTAssertEqual(s, [.init(fileName: "azul.pdf", target: .new(name: "Azul"), role: .core, title: "Azul", reason: "base rules", notARulebook: false)])
        XCTAssertEqual(SorterStubAPI.seen.count, 1)
    }

    func testErrorsAndCutOffRepliesThrow() async {
        SorterStubAPI.status = 400
        SorterStubAPI.reply = #"{"type":"error","error":{"type":"invalid_request_error","message":"model not allowed"}}"#
        do { _ = try await sorter().sort(files, games: []); XCTFail("expected an error") } catch let e as ClaudeAPIError {
            XCTAssertEqual(e.status, 400)
        } catch { XCTFail("\(error)") }

        SorterStubAPI.status = 200
        SorterStubAPI.reply = SorterStubAPI.sse(text: #"{"files":[{"index":1,"#, stop: "max_tokens")
        do { _ = try await sorter().sort(files, games: []); XCTFail("expected an error") } catch {
            XCTAssertEqual(error as? RulebookSorter.SortError, .stopped("max_tokens"))
        }
    }
}
