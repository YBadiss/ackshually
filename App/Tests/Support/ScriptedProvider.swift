import XCTest
import Synchronization
import AckshuallyCore
@testable import Ackshually

/// An `AnswerProvider` the test drives: each `answer(_:)` call opens a stream, and the test sends its events
/// (or an error) one at a time. No timers, no sleeps.
final class ScriptedProvider: AnswerProvider {
    private struct State {
        var requests: [AnswerRequest] = []
        var streams: [AsyncThrowingStream<AnswerEvent, Error>.Continuation] = []
    }
    private let state = Mutex(State())

    var requests: [AnswerRequest] { state.withLock { $0.requests } }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, Error> {
        let (stream, c) = AsyncThrowingStream.makeStream(of: AnswerEvent.self, throwing: Error.self)
        state.withLock { $0.requests.append(request); $0.streams.append(c) }
        return stream
    }

    /// Sends to the latest stream.
    func send(_ events: AnswerEvent...) {
        guard let c = state.withLock({ $0.streams.last }) else { return XCTFail("nothing asked yet") }
        for e in events { c.yield(e) }
    }

    func fail(_ error: Error) {
        state.withLock { $0.streams.last }?.finish(throwing: error)
    }

    /// The events of a whole answer, in the contract's order (steps, then branches).
    static func events(for a: Answer) -> [AnswerEvent] {
        var out: [AnswerEvent] = [.firstToken, .restatedQuestion(a.restatedQuestion), .verdict(a.verdict), .confidence(a.confidence)]
        for (i, s) in a.steps.enumerated() {
            out += s.evidence.enumerated().map { .evidence(step: i, index: $0, $1) }
            out.append(.step(index: i, s))
        }
        out += a.branches.map(AnswerEvent.branch)
        out.append(.completed(AnswerResult(answer: a, rawText: "{raw}", usage: TokenUsage(), model: "scripted",
                                           stopReason: "end_turn", parseError: nil)))
        return out
    }
}

/// Answers every question with one `ScriptedProvider` through `route` (nil: no credential, like a real
/// rulebook without a token).
struct ScriptedProviders: AnswerProviderFactory {
    let provider = ScriptedProvider()
    var route: AnswerRoute.Kind? = .server

    func provider(isSample: Bool) -> (provider: any AnswerProvider, route: AnswerRoute.Kind)? {
        route.map { (provider, $0) }
    }
    var claudeRoute: AnswerRoute.Kind? { route == .demo ? nil : route }
    var serverHost: String { "server.test" }
}

/// Counts how often each passage is placed; places instantly on the cited page.
final class CountingPlacer: Sendable {
    private let counts = Mutex<[String: Int]>([:])

    func count(_ e: Evidence) -> Int { counts.withLock { $0[HighlightStore.key(e)] ?? 0 } }
    var total: Int { counts.withLock { $0.values.reduce(0, +) } }

    var place: HighlightStore.Placer {
        { [self] e in
            counts.withLock { $0[HighlightStore.key(e), default: 0] += 1 }
            return Highlight(page: e.page, kind: .wholePage)
        }
    }
}

@MainActor
extension XCTestCase {
    /// Lets the main actor run (the session's stream task, highlight tasks) until `condition` holds.
    func until(_ what: String = "condition", file: StaticString = #filePath, line: UInt = #line,
               _ condition: () -> Bool) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("timed out waiting for \(what)", file: file, line: line)
    }

    /// Asks through the viewer and waits until the question reached the provider (its stream is open).
    func ask(_ viewer: ViewerModel, _ question: String, _ provider: ScriptedProvider,
             file: StaticString = #filePath, line: UInt = #line) async {
        let n = provider.requests.count
        viewer.session.ask(question)
        await until("request", file: file, line: line) { provider.requests.count == n + 1 }
    }

    /// A viewer session on the sample rulebook answered by `providers`.
    func makeViewer(_ providers: ScriptedProviders = ScriptedProviders(), placer: CountingPlacer = CountingPlacer()) -> ViewerModel {
        ViewerModel(rulebook: Fixtures.rulebook(), providers: providers, place: placer.place)
    }
}

let battery = DemoProvider.batteryAnswer
let batteryQuestion = "what happens to my energy at end of turn if I have the battery"
