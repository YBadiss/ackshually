import Foundation
import AckshuallyCore

/// Launch arguments for the simulator and screenshots (they land in UserDefaults' argument domain):
/// The app opens on My Games (S1). Opening a document pushes the viewer on top of the list
/// (Back returns to it); those documents are not added to My Games.
///   -pdfPath /abs/file.pdf     open this PDF (simulator can read host paths)
///   -sample YES                open the generated sample rulebook
///   -emptyLibrary YES          start with no games (clears the index and the imported copies)
///   -seedSample YES            add the sample to My Games, like "Try the Sample" (persisted)
///   -demo YES                  scripted answers, no API calls (also when no key is set)
///   -demoAnswer /abs/a.json    scripted Answer JSON (spec §4 contract) for the demo provider
///   -demoPace 3                stretch the demo stream's delays (UI tests sample the sheet while it streams);
///                              -demoPace 0 streams the whole demo answer at once (UI tests that only need the result)
///   -ask "question"            ask right away
///   -present YES               show the demo answer instantly (no streaming)
///   -detent collapsed|medium|expanded,  -card N (0-based step)
///   -noKey YES                 ignore every credential (bundled token, token override, API key)
/// Debug builds only (UI tests; see `ServerConfig`, `CredentialStore`):
///   -serverURL http://127.0.0.1:N   a local stub instead of the ackshually server
///   -appToken fake-token            replaces the bundled token (never a real one)
///   -isolatedCredentials YES        separate, emptied Keychain items; ignores the real bundled token
@MainActor
enum LaunchOptions {
    static func apply(to library: LibraryModel) {
        let d = UserDefaults.standard
        CredentialStore.resetIsolatedIfRequested()
        if d.bool(forKey: "emptyLibrary") { library.reset() }
        if d.bool(forKey: "seedSample") { library.seedSample() }
        if let p = d.string(forKey: "pdfPath") {
            // Launch-argument documents (UI tests, screenshots) are never added to My Games, so
            // test runs don't change the list the app shows on the next normal launch.
            library.openTransient(URL(fileURLWithPath: p))
        } else if d.bool(forKey: "sample") {
            library.openSampleTransient()
        }
        guard let model = library.current else { return }
        if d.bool(forKey: "present") {
            let a = d.string(forKey: "demoAnswer").flatMap(DemoProvider.answer(fromFile:)) ?? DemoProvider.batteryAnswer
            model.present(LiveAnswer(question: d.string(forKey: "ask") ?? a.restatedQuestion, answer: a), phase: .done)
        } else if let q = d.string(forKey: "ask") {
            model.session.ask(q)
        }
                if let c = d.object(forKey: "card") as? String, let i = Int(c) { model.navigator.selectStep(i) }
        switch d.string(forKey: "detent") {
        case "collapsed": model.detent = .collapsed
        case "expanded": model.detent = .expanded
        default: break
        }
    }
}
