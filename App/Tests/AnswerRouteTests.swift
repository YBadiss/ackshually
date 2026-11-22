import XCTest
import AckshuallyCore
@testable import Ackshually

/// Records each request and answers with a canned status and body (SSE for 200).
final class RouteStubProtocol: URLProtocol {
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var status = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.seen.append(request)
        let ok = Self.status == 200
        let body = ok
            ? #"data: {"type":"message_start","message":{"model":"m","usage":{"input_tokens":1,"output_tokens":1}}}"# + "\n\n"
            : #"{"type":"error","error":{"type":"authentication_error","message":"Missing or unknown app token"}}"#
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil,
                                   headerFields: ["content-type": ok ? "text/event-stream" : "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class AnswerRouteTests: XCTestCase {
    private let server = URL(string: "https://server.test")!

    private func run(_ route: AnswerRoute, status: Int = 200) async -> (URLRequest?, Error?) {
        RouteStubProtocol.seen = []
        RouteStubProtocol.status = status
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [RouteStubProtocol.self]
        let p = ClaudeProvider(config: route.claudeConfig(model: "claude-sonnet-5-5"), session: URLSession(configuration: c))
        var error: Error?
        do {
            for try await _ in p.answer(AnswerRequest(pdf: Data([1]), documentTitle: "T", question: "Q")) {}
        } catch let e { error = e }
        return (RouteStubProtocol.seen.first, error)
    }

    // MARK: Precedence

    func testPrecedenceBundledThenOverrideThenKey() {
        XCTAssertEqual(AnswerRoute.resolve(bundledToken: "b", tokenOverride: "o", apiKey: "k", serverURL: server),
                       .server(token: "b", url: server))
        XCTAssertEqual(AnswerRoute.resolve(bundledToken: nil, tokenOverride: "o", apiKey: "k", serverURL: server),
                       .server(token: "o", url: server))
        XCTAssertEqual(AnswerRoute.resolve(bundledToken: "", tokenOverride: nil, apiKey: "k", serverURL: server),
                       .direct(apiKey: "k"))
        XCTAssertNil(AnswerRoute.resolve(bundledToken: nil, tokenOverride: "", apiKey: nil, serverURL: server))
    }

    func testDescriptionNeverContainsTheCredential() {
        XCTAssertFalse(AnswerRoute.server(token: "ack_secret", url: server).description.contains("ack_secret"))
        XCTAssertFalse(AnswerRoute.direct(apiKey: "sk-secret").description.contains("sk-secret"))
    }

    func testBuiltInServerURLComesFromInfoPlist() {
        let s = Bundle.main.object(forInfoDictionaryKey: ServerConfig.urlKey) as? String
        XCTAssertEqual(s, "https://ackshually.badyass.xyz")
    }

    // MARK: Requests

    func testServerRouteSendsBearerToServerWithoutAPIKey() async throws {
        let (req, _) = await run(.server(token: "fake-token", url: server))
        let r = try XCTUnwrap(req)
        XCTAssertEqual(r.url?.absoluteString, "https://server.test/v1/messages")
        XCTAssertEqual(r.value(forHTTPHeaderField: "authorization"), "Bearer fake-token")
        XCTAssertNil(r.value(forHTTPHeaderField: "x-api-key"))
    }

    func testDirectRouteSendsAPIKeyToAnthropic() async throws {
        let (req, _) = await run(.direct(apiKey: "sk-fake"))
        let r = try XCTUnwrap(req)
        XCTAssertEqual(r.url?.host(), "api.anthropic.com")
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-api-key"), "sk-fake")
        XCTAssertNil(r.value(forHTTPHeaderField: "authorization"))
    }

    func testServer401BecomesSettingsMessage() async throws {
        let (_, error) = await run(.server(token: "revoked", url: server), status: 401)
        let f = AnswerFailure(try XCTUnwrap(error), route: .server)
        XCTAssertTrue(f.opensSettings)
        XCTAssertTrue(f.message.contains("access token"), f.message)
        XCTAssertTrue(f.message.contains("Settings"), f.message)
    }

    // MARK: Messages

    private static func body(_ message: String) -> String {
        #"{"type":"error","error":{"type":"rate_limit_error","message":"\#(message)"}}"#
    }

    func testRateLimitAndDailyCapMessages() {
        let burst = AnswerFailure(ClaudeAPIError(status: 429, body: Self.body("Too many requests, try again shortly"), retryAfter: 20),
                                  route: .server)
        XCTAssertEqual(burst.message, "Too many questions at once. Try again in 20 seconds.")
        XCTAssertFalse(burst.opensSettings)

        let daily = AnswerFailure(ClaudeAPIError(status: 429, body: Self.body("Today's usage limit is reached, try again tomorrow")),
                                  route: .server)
        XCTAssertEqual(daily.message, "Today's question limit is reached. Try again tomorrow.")
        XCTAssertFalse(daily.opensSettings)

        let direct = AnswerFailure(ClaudeAPIError(status: 429, body: ""), route: .direct)
        XCTAssertEqual(direct.message, "Too many questions at once. Try again in a moment.")
    }

    func testOtherServerErrors() {
        let key = AnswerFailure(ClaudeAPIError(status: 401, body: ""), route: .direct)
        XCTAssertEqual(key.message, "Anthropic rejected your API key. Check it in Settings.")
        XCTAssertTrue(key.opensSettings)
        XCTAssertEqual(AnswerFailure(ClaudeAPIError(status: 502, body: ""), route: .server).message,
                       "The server couldn't reach Claude. Try again in a moment.")
        XCTAssertEqual(AnswerFailure(URLError(.cannotConnectToHost), route: .server).message,
                       "Couldn't reach the ackshually server. Try again in a moment.")
        let refused = #"{"type":"error","error":{"type":"invalid_request_error","message":"model not allowed"}}"#
        XCTAssertEqual(AnswerFailure(ClaudeAPIError(status: 400, body: refused), route: .server).message,
                       "Something went wrong (HTTP 400): model not allowed")
    }
}
