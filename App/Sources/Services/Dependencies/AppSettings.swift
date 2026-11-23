import Foundation
import AckshuallyCore

/// User settings and the answer-related launch flags. Live: `UserDefaultsSettings` (Settings' toggle and the
/// launch arguments, which land in UserDefaults' argument domain); previews and tests: `InMemorySettings`.
protocol AppSettings: Sendable {
    /// Settings → Demo Answers, or `-demo YES`: the scripted demo even when a credential is set up.
    var demoAnswers: Bool { get nonmutating set }
    /// `-demoAnswer /abs/a.json`: the scripted answer the demo streams (spec §4 contract).
    var demoAnswer: Answer? { get }
    /// `-demoPace N`: stretch the demo stream's delays (0 = instant).
    var demoPace: Double { get }
}

struct UserDefaultsSettings: AppSettings {
    private var defaults: UserDefaults { .standard }

    var demoAnswers: Bool {
        get { defaults.bool(forKey: "demo") }
        nonmutating set { defaults.set(newValue, forKey: "demo") }
    }

    var demoAnswer: Answer? { defaults.string(forKey: "demoAnswer").flatMap(DemoProvider.answer(fromFile:)) }

    var demoPace: Double { (defaults.object(forKey: "demoPace") as? String).flatMap(Double.init) ?? 1 }
}
