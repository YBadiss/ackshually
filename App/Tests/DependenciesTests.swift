import XCTest
import AckshuallyCore
@testable import Ackshually

/// Who answers (`LiveAnswerProviders`) and what Settings saves (`SettingsModel`), with in-memory credentials.
@MainActor
final class DependenciesTests: XCTestCase {
    func testProviderChoice() {
        let none = LiveAnswerProviders(credentials: InMemoryCredentials(), settings: InMemorySettings())
        XCTAssertEqual(none.provider(isSample: true)?.route, .demo, "the sample still gets the scripted demo")
        XCTAssertNil(none.provider(isSample: false), "a real rulebook without a credential: nobody answers")
        XCTAssertNil(none.claudeRoute)

        let token = LiveAnswerProviders(credentials: InMemoryCredentials(bundledToken: "fake"), settings: InMemorySettings())
        XCTAssertEqual(token.provider(isSample: true)?.route, .server)
        // Wrapped in page selection, which only steps in for documents too large to send whole (several joined
        // books); everything else reaches Claude unchanged.
        XCTAssertTrue(token.provider(isSample: false)?.provider is PageSelectingProvider)
        XCTAssertEqual(token.serverHost, "ackshually.badyass.xyz")

        let demo = LiveAnswerProviders(credentials: InMemoryCredentials(bundledToken: "fake"), settings: InMemorySettings(demoAnswers: true))
        XCTAssertEqual(demo.provider(isSample: true)?.route, .demo, "Demo Answers wins over a credential")
        XCTAssertTrue(demo.provider(isSample: false)?.provider is DemoProvider)
    }

    func testSettingsSavesCredentialsAndDemoFlag() {
        let credentials = InMemoryCredentials()
        let settings = InMemorySettings()
        let model = SettingsModel(credentials: credentials, settings: settings)
        XCTAssertEqual(model.status.active, .none)
        model.save(" fake-override ", for: .tokenOverride)
        XCTAssertEqual(model.status.active, .tokenOverride)
        XCTAssertEqual(credentials.route, .server(token: "fake-override", url: URL(string: "https://ackshually.badyass.xyz")!))
        model.save("sk-x", for: .apiKey)
        XCTAssertTrue(model.status.apiKeySaved)
        model.save(nil, for: .tokenOverride)
        XCTAssertEqual(model.status.active, .apiKey(fromEnvironment: false))
        XCTAssertEqual(credentials.route, .direct(apiKey: "sk-x"))

        model.demoAnswers = true
        XCTAssertTrue(settings.demoAnswers)
    }
}
