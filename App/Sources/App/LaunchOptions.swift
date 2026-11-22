import Foundation
import AckshuallyCore

/// Launch arguments for the simulator and screenshots (they land in UserDefaults' argument domain):
///   -pdfPath /abs/file.pdf     open this PDF (simulator can read host paths)
///   -sample YES                open the generated sample rulebook
///   -demo YES                  scripted answers, no API calls (also when no key is set)
///   -demoAnswer /abs/a.json    scripted Answer JSON (spec §4 contract) for the demo provider
///   -ask "question"            ask right away
///   -present YES               show the demo answer instantly (no streaming)
///   -detent collapsed|medium|expanded,  -card N (0-based step),  -branch N
///   -noKey YES                 ignore every credential (bundled token, token override, API key)
/// Debug builds only (UI tests; see `ServerConfig`, `CredentialStore`):
///   -serverURL http://127.0.0.1:N   a local stub instead of the ackshually server
///   -appToken fake-token            replaces the bundled token (never a real one)
///   -isolatedCredentials YES        separate, emptied Keychain items; ignores the real bundled token
@MainActor
enum LaunchOptions {
    static func apply(to model: ViewerModel) {
        let d = UserDefaults.standard
        CredentialStore.resetIsolatedIfRequested()
        if let p = d.string(forKey: "pdfPath") {
            // Launch-argument documents (UI tests, screenshots) are never remembered, so test runs
            // don't decide what the app opens on the next normal launch.
            model.open(URL(fileURLWithPath: p), remember: false)
        } else if d.bool(forKey: "sample") {
            model.openSample(remember: false)
        } else if model.rulebook == nil, let last = Library.last {
            model.open(last)
        }
        guard model.rulebook != nil else { return }
        if d.bool(forKey: "present") {
            let a = d.string(forKey: "demoAnswer").flatMap(DemoProvider.answer(fromFile:)) ?? DemoProvider.batteryAnswer
            model.present(LiveAnswer(question: d.string(forKey: "ask") ?? a.restatedQuestion, answer: a), phase: .done)
        } else if let q = d.string(forKey: "ask") {
            model.ask(q)
        }
        if let b = d.object(forKey: "branch") as? String, let i = Int(b) { model.selectBranch(i) }
        if let c = d.object(forKey: "card") as? String, let i = Int(c) { model.selectStep(i) }
        switch d.string(forKey: "detent") {
        case "collapsed": model.detent = .collapsed
        case "expanded": model.detent = .expanded
        default: break
        }
    }
}
