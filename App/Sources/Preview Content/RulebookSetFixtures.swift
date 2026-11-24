import Foundation
import AckshuallyCore

/// A game with two books (S13): the sample (Power Plant Rush, core) and its made-up Solar Expansion (add-on),
/// joined like the app joins them. Quotes are verbatim from the generated pages: joined page 4 is the base
/// game's Battery page, joined page 6 is Solar p.2, whose Battery rule overrides it.
@MainActor
extension Fixtures {
    static let solarURL: URL = {
        let u = FileManager.default.temporaryDirectory.appending(path: "solar-expansion.pdf")
        if !FileManager.default.fileExists(atPath: u.path) { _ = try? FixtureRulebook.write(to: u, pages: FixtureRulebook.expansionPages) }
        return u
    }()

    /// "Power Plant Rush p.4, Solar Expansion p.2": cited pages of the two-book answer.
    static let bookPages = [PageReference(book: "Power Plant Rush", page: 4), PageReference(book: "Solar Expansion", page: 2)]

    /// The two books joined (a fresh document per call: each session owns its documents).
    static func setRulebook(notInPlay: [String] = []) -> LoadedRulebook {
        guard let base = try? Data(contentsOf: rulebookURL), let solar = try? Data(contentsOf: solarURL),
              let j = RulebookJoiner.join([RulebookSource(title: "Power Plant Rush", role: .core, pdf: base),
                                           RulebookSource(title: "Solar Expansion", role: .addOn, pdf: solar)],
                                          gameTitle: "Power Plant Rush", notInPlay: notInPlay),
              let rb = LoadedRulebook(title: "Power Plant Rush", data: j.pdf, contents: j.contents,
                                      fileNames: [Library.sampleFileName, Library.sampleExpansionFileName])
        else { preconditionFailure("fixture rulebooks") }
        return rb
    }

    static let solarAnswer = Answer(
        restatedQuestion: "You own a Battery and have 3 unused energy at the end of your turn, playing with the Solar Expansion.",
        verdict: "Keep all 3 energy: Solar raises the Battery to 3.",
        confidence: .stated,
        assumptions: ["The Solar Expansion is in play."],
        steps: [
            Step(title: "Base Battery", text: "In the base game a Battery keeps up to 2 unused energy.",
                 evidence: [Evidence(page: 4, quote: "a player who owns a Battery keeps up to 2 unused energy")]),
            Step(title: "Solar overrides it", text: "The Solar Expansion changes the base rule: a Battery keeps up to 3.",
                 evidence: [Evidence(page: 6, quote: "a player who owns a Battery keeps up to 3 unused energy at the end of the turn"),
                            Evidence(page: 3, quote: "at the end of your turn you must discard all unused energy")]),
            Step(title: "Your 3 energy", text: "All 3 stay on your Battery for next turn; nothing is discarded.",
                 evidence: [Evidence(page: 6, quote: "a player who owns a Battery keeps up to 3 unused energy at the end of the turn")]),
        ])

    /// The viewer on the two-book game, answered (or idle).
    static func setModel(answered: Bool = true, card: Int? = nil, dependencies: AppDependencies = .preview) -> ViewerModel {
        let m = ViewerModel(rulebook: setRulebook(), providers: dependencies.providers, route: .game(id: Library.sampleFileName))
        guard answered else { return m }
        m.present(LiveAnswer(question: "battery with solar, keep 2 or 3?", answer: solarAnswer), phase: .done)
        if let card { m.navigator.selectStep(card) }
        return m
    }

    static let headerSet = HeaderContent(state: .answered, question: solarAnswer.restatedQuestion, verdict: solarAnswer.verdict,
                                         confidence: .stated, pages: bookPages)

    static let cardWithBook: StepCardContent = .step(number: 2, title: "Solar overrides it",
                                                     pages: [PageReference(book: "Solar Expansion", page: 2),
                                                             PageReference(book: "Power Plant Rush", page: 3)],
                                                     text: solarAnswer.steps[1].text, figure: false)
}
