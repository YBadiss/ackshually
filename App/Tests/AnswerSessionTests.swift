import XCTest
import AckshuallyCore
@testable import Ackshually

/// Asking, streaming, stop, retry, failures and follow-ups, against a scripted provider (formerly only
/// covered by UI tests that waited for the demo stream).
@MainActor
final class AnswerSessionTests: XCTestCase {
    private var providers = ScriptedProviders()
    private var viewer: ViewerModel!
    private var session: AnswerSession { viewer.session }
    private var provider: ScriptedProvider { providers.provider }

    override func setUp() async throws {
        providers = ScriptedProviders()
        viewer = makeViewer(providers)
    }

    func testStreamingGoesFromWaitingToFirstTokenToStepsToCompleted() async {
        await ask(viewer, "  \(batteryQuestion)\n", provider)
        XCTAssertEqual(session.phase, .waiting)
        XCTAssertEqual(session.answer?.question, batteryQuestion, "trimmed")
        XCTAssertEqual(session.draft, "")
        XCTAssertEqual(provider.requests.first?.question, batteryQuestion)
        XCTAssertTrue(provider.requests.first?.history.isEmpty ?? false)

        provider.send(.firstToken)
        await until("streaming") { session.phase == .streaming }
        XCTAssertEqual(viewer.navigator.cards, [.loading], "a loading card holds the shelf's place from the first token")
        XCTAssertEqual(viewer.navigator.header?.state, .arriving)

        provider.send(.restatedQuestion(battery.restatedQuestion), .verdict(battery.verdict), .confidence(.stated))
        await until("verdict") { session.answer?.verdict != nil }
        XCTAssertEqual(viewer.navigator.header?.state, .answered)
        XCTAssertEqual(viewer.navigator.header?.question, battery.restatedQuestion)
        XCTAssertNil(viewer.navigator.cardID, "no card is current until step 1 arrives")

        provider.send(.step(index: 0, battery.steps[0]))
        await until("step 1") { session.answer?.steps.count == 1 }
        XCTAssertEqual(viewer.navigator.cards, [.step(0), .loading])
        XCTAssertEqual(viewer.navigator.cardID, .step(0), "step 1 becomes current when it arrives (S4)")
        XCTAssertFalse(session.canFollowUp, "follow-ups wait for the answer")

        for e in ScriptedProvider.events(for: battery).drop(while: { if case .step(index: 0, _) = $0 { false } else { true } }).dropFirst() {
            provider.send(e)
        }
        await until("done") { session.phase == .done }
        XCTAssertEqual(session.answer?.complete, true)
        XCTAssertEqual(viewer.navigator.cards, [.step(0), .step(1), .step(2)], "no loading card and no closing Result card")
        XCTAssertEqual(session.turns.count, 1)
        XCTAssertEqual(session.turns.first?.rawAssistantText, "{raw}")
        XCTAssertTrue(session.canFollowUp)
        XCTAssertEqual(session.route, .server)
    }

    func testStopBeforeFirstStepPutsTheQuestionBack() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(.firstToken, .verdict(battery.verdict))
        await until { session.answer?.verdict != nil }
        session.stop()
        XCTAssertNil(session.answer)
        XCTAssertEqual(session.draft, batteryQuestion, "back in the field to rephrase")
        XCTAssertEqual(session.phase, .done)
        XCTAssertFalse(viewer.sheetVisible)
        // Events after Stop are ignored.
        provider.send(.step(index: 0, battery.steps[0]))
        await Task.yield()
        XCTAssertNil(session.answer)
    }

    func testStopAfterFirstStepKeepsWhatArrived() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(.firstToken, .verdict(battery.verdict), .step(index: 0, battery.steps[0]))
        await until { session.answer?.steps.count == 1 }
        session.stop()
        XCTAssertEqual(session.answer?.stopped, true)
        XCTAssertEqual(session.answer?.steps.count, 1)
        XCTAssertEqual(viewer.navigator.cards, [.step(0)], "the loading card goes away")
        XCTAssertTrue(viewer.sheetVisible)
        XCTAssertTrue(session.canFollowUp)
        XCTAssertEqual(viewer.navigator.header?.stopped, true)
    }

    func testFailureShowsMessageAndRetryAsksAgain() async {
        await ask(viewer, batteryQuestion, provider)
        provider.fail(ClaudeAPIError(status: 429, body: "", retryAfter: 30))
        await until("failed") { if case .failed = session.phase { true } else { false } }
        guard case .failed(let f) = session.phase else { return }
        XCTAssertEqual(f.message, "Too many questions at once. Try again in 30 seconds.")
        XCTAssertFalse(f.opensSettings)
        XCTAssertTrue(viewer.sheetVisible, "the failure shows in the sheet")
        XCTAssertTrue(session.canFollowUp)

        session.retry()
        XCTAssertEqual(session.phase, .waiting)
        await until("retried") { provider.requests.count == 2 }
        XCTAssertEqual(provider.requests.count, 2)
        XCTAssertEqual(provider.requests.last?.question, batteryQuestion)
    }

    func testRejectedTokenOffersSettings() async {
        await ask(viewer, batteryQuestion, provider)
        provider.fail(ClaudeAPIError(status: 401, body: #"{"type":"error","error":{"type":"authentication_error"}}"#))
        await until { if case .failed = session.phase { true } else { false } }
        guard case .failed(let f) = viewer.navigator.header?.state else { return XCTFail("failed header") }
        XCTAssertTrue(f.opensSettings, "the error header offers Open Settings")
        XCTAssertTrue(f.message.contains("access token"), f.message)
        XCTAssertFalse(viewer.presentation.settings, "Settings opens only from the button")
    }

    func testUnreadableAnswerFails() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(.firstToken, .completed(AnswerResult(answer: nil, rawText: "{", usage: TokenUsage(), model: "m",
                                                           stopReason: "max_tokens", parseError: "truncated")))
        await until { if case .failed = session.phase { true } else { false } }
        guard case .failed(let f) = session.phase else { return }
        XCTAssertEqual(f.message, "The answer couldn't be read (truncated).")
        XCTAssertTrue(session.turns.isEmpty)
    }

    func testRealRulebookWithoutCredentialOpensSettingsAndKeepsQuestion() {
        providers.route = nil
        viewer = makeViewer(providers)
        session.ask("Can I pass?")
        XCTAssertNil(session.answer)
        XCTAssertEqual(session.draft, "Can I pass?")
        XCTAssertTrue(viewer.presentation.settings)
        XCTAssertTrue(provider.requests.isEmpty)
    }

    func testFollowUpKeepsHistory() async {
        await ask(viewer, batteryQuestion, provider)
        provider.send(contentsOf: ScriptedProvider.events(for: battery))
        await until { session.phase == .done }
        let first = session.answer?.id
        session.rate(true)
        XCTAssertEqual(session.currentRating, true)

        await ask(viewer, "And with two Batteries?", provider)
        XCTAssertEqual(provider.requests.count, 2)
        let follow = provider.requests[1]
        XCTAssertEqual(follow.question, "And with two Batteries?")
        XCTAssertEqual(follow.history.map(\.question), [batteryQuestion], "Core replays the earlier turn")
        XCTAssertEqual(follow.history.first?.rawAssistantText, "{raw}")
        XCTAssertNotEqual(session.answer?.id, first)
        XCTAssertNil(session.currentRating, "feedback is per answer")
        provider.send(contentsOf: ScriptedProvider.events(for: battery))
        await until { session.phase == .done }
        XCTAssertEqual(session.turns.count, 2)
    }

    func testFeedbackToggles() {
        viewer.present(LiveAnswer(question: "q", answer: battery), phase: .done)
        session.rate(false)
        XCTAssertEqual(session.currentRating, false)
        session.rate(false)
        XCTAssertNil(session.currentRating, "tapping the same thumb again clears it")
    }
}

extension ScriptedProvider {
    func send(contentsOf events: [AnswerEvent]) { for e in events { send(e) } }
}
