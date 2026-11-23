import Foundation
import AckshuallyCore

/// Who answers a question about a rulebook: Claude through the route the credentials give, the scripted demo,
/// or nobody (a real rulebook without a credential: Settings opens). Live: `LiveAnswerProviders`; unit tests
/// inject a scripted provider, previews the instant demo.
protocol AnswerProviderFactory: Sendable {
    /// nil: no credential and not a demo-able rulebook.
    func provider(isSample: Bool) -> (provider: any AnswerProvider, route: AnswerRoute.Kind)?
    /// The route Claude would answer through: nil without a credential (the ⋯ menu then notes "Demo answers:
    /// no access token set").
    var claudeRoute: AnswerRoute.Kind? { get }
    /// Answer Details' "Answered by: ackshually server · host".
    var serverHost: String { get }
}

/// Claude through the route the credentials give (token → server, else API key → direct); the scripted
/// demo only for the sample rulebook (or Demo Answers / `-demo YES`).
struct LiveAnswerProviders: AnswerProviderFactory {
    /// The M1 answer config (`json` evidence, effort `low`, in `AnswerRoute.claudeConfig`).
    static let model = "claude-sonnet-5-5"
    var credentials: any CredentialAccess
    var settings: any AppSettings

    func provider(isSample: Bool) -> (provider: any AnswerProvider, route: AnswerRoute.Kind)? {
        let demo = settings.demoAnswers
        if !demo, let route = credentials.route {
            return (ClaudeProvider(config: route.claudeConfig(model: Self.model)), route.kind)
        }
        guard isSample || demo else { return nil }
        return (DemoProvider(answer: settings.demoAnswer ?? DemoProvider.batteryAnswer, pace: settings.demoPace), .demo)
    }

    var claudeRoute: AnswerRoute.Kind? { credentials.route?.kind }

    var serverHost: String { credentials.status.serverHost }
}
