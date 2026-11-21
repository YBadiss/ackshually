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
@MainActor
enum LaunchOptions {
    static func apply(to model: ViewerModel) {
        let d = UserDefaults.standard
        if let p = d.string(forKey: "pdfPath") {
            model.open(URL(fileURLWithPath: p))
        } else if d.bool(forKey: "sample") {
            model.openSample()
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
