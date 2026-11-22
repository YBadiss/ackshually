import XCTest
@testable import AckshuallyCore

/// Answers every request with the canned status, headers and body in `next`, and records what was sent.
final class ErrorStubAPI: URLProtocol {
    struct Canned: Sendable { var status: Int; var headers: [String: String]; var body: String }
    nonisolated(unsafe) static var next = Canned(status: 401, headers: [:], body: "")
    nonisolated(unsafe) static var seen: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.seen.append(request)
        let c = Self.next
        let resp = HTTPURLResponse(url: request.url!, statusCode: c.status, httpVersion: nil,
                                   headerFields: ["content-type": "application/json"].merging(c.headers) { $1 })!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(c.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// The server (`Server/`) answers errors in Anthropic's shape; Core surfaces status, type, message and retry-after.
final class ServerRouteTests: XCTestCase {
    private func provider() -> ClaudeProvider {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [ErrorStubAPI.self]
        return ClaudeProvider(config: ClaudeConfig(credential: .appToken("ack_test"), baseURL: URL(string: "https://server.test")!),
                              session: URLSession(configuration: c))
    }

    private func error(_ canned: ErrorStubAPI.Canned) async throws -> ClaudeAPIError {
        ErrorStubAPI.next = canned
        ErrorStubAPI.seen = []
        do {
            for try await _ in provider().answer(AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q")) {}
        } catch let e as ClaudeAPIError {
            return e
        }
        XCTFail("expected a ClaudeAPIError")
        throw CancellationError()
    }

    private static func body(_ type: String, _ message: String) -> String {
        #"{"type":"error","error":{"type":"\#(type)","message":"\#(message)"}}"#
    }

    func testUnauthorizedCarriesTypeAndMessage() async throws {
        let e = try await error(.init(status: 401, headers: [:], body: Self.body("authentication_error", "Missing or unknown app token")))
        XCTAssertEqual(e.status, 401)
        XCTAssertEqual(e.errorType, "authentication_error")
        XCTAssertEqual(e.message, "Missing or unknown app token")
        XCTAssertNil(e.retryAfter)
        let sent = try XCTUnwrap(ErrorStubAPI.seen.first)
        XCTAssertEqual(sent.url?.absoluteString, "https://server.test/v1/messages")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "authorization"), "Bearer ack_test")
        XCTAssertNil(sent.value(forHTTPHeaderField: "x-api-key"))
    }

    func testRateLimitKeepsRetryAfterAndDailyCapHasNone() async throws {
        let burst = try await error(.init(status: 429, headers: ["retry-after": "17"],
                                          body: Self.body("rate_limit_error", "Too many requests, try again shortly")))
        XCTAssertEqual(burst.retryAfter, 17)
        XCTAssertEqual(burst.errorType, "rate_limit_error")
        let daily = try await error(.init(status: 429, headers: [:],
                                          body: Self.body("rate_limit_error", "Today's usage limit is reached, try again tomorrow")))
        XCTAssertNil(daily.retryAfter)
        XCTAssertEqual(daily.message, "Today's usage limit is reached, try again tomorrow")
    }

    func testNonJSONBodyHasNoDetails() async throws {
        let e = try await error(.init(status: 502, headers: [:], body: "<html>Bad Gateway</html>"))
        XCTAssertEqual(e.status, 502)
        XCTAssertNil(e.errorType)
        XCTAssertNil(e.message)
    }
}
