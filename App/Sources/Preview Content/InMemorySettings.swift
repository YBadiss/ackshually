import Foundation
import Synchronization
import AckshuallyCore

/// Settings kept in memory (previews, unit tests).
final class InMemorySettings: AppSettings {
    private let demo: Mutex<Bool>
    let demoAnswer: Answer?
    let demoPace: Double

    init(demoAnswers: Bool = false, demoAnswer: Answer? = nil, demoPace: Double = 1) {
        demo = Mutex(demoAnswers)
        self.demoAnswer = demoAnswer
        self.demoPace = demoPace
    }

    var demoAnswers: Bool {
        get { demo.withLock { $0 } }
        set { demo.withLock { $0 = newValue } }
    }
}
