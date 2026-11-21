import Foundation
import PDFKit
import AckshuallyCore

/// Shared preview fixtures, built on Core's fake rulebook ("Power Plant Rush") so every screen
/// can be iterated on without an API key. Quotes are verbatim from the fixture pages.
@MainActor
enum Fixtures {
    static let answer = DemoProvider.batteryAnswer
    static let branches = answer.branches + [Branch(condition: "Two Batteries", verdict: "Keep all 3.")]

    static let rulebookURL: URL = {
        let u = FileManager.default.temporaryDirectory.appending(path: "power-plant-rush.pdf")
        if !FileManager.default.fileExists(atPath: u.path) { _ = try? FixtureRulebook.write(to: u) }
        return u
    }()

    static let pdf: PDFDocument = PDFDocument(url: rulebookURL) ?? PDFDocument()

    static func focus(_ zoom: ZoomMode) -> PDFFocus {
        let matcher = QuoteMatcher(document: PDFDocument(url: rulebookURL) ?? PDFDocument())
        let h = HighlightPlacer.place(answer.steps[1].evidence[0], matcher: matcher)
        return PDFFocus(token: 1, highlight: h, zoom: zoom)
    }

    // MARK: Header states

    static let headerArriving = HeaderContent(state: .arriving, question: answer.restatedQuestion, isBusy: true)
    static let headerStreaming = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: answer.verdict,
                                               confidence: .stated, pages: [3], branches: answer.branches, isBusy: true)
    static let headerStated = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: answer.verdict,
                                            confidence: .stated, pages: [3, 4], branches: answer.branches)
    static let headerInferred = HeaderContent(state: .answered, question: "Can I trade energy for coins with another player?",
                                              verdict: "No: energy can't be traded at all, so not for coins either.",
                                              confidence: .inferred, pages: [3])
    static let headerNotCovered = HeaderContent(state: .answered, question: "Can a Windmill be sold back?",
                                                verdict: "Probably not; the rules don't mention selling plants.",
                                                confidence: .notCovered, pages: [])
    static let headerBranchActive = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: answer.verdict,
                                                  confidence: .stated, pages: [3, 4], branches: branches, activeBranch: 0, demo: true)
    static let headerFailed = HeaderContent(state: .failed("The API key was rejected. Check it in Settings."),
                                            question: "Can I keep energy?")

    // MARK: Cards

    static let cardStates: [StepCardContent] = [
        .step(number: 1, title: "Rule", pages: [3], text: answer.steps[0].text, figure: false),
        .step(number: 2, title: "Step", pages: [4], text: "The scoring track shows 1 point per 3 energy spent.", figure: true),
        .loading(number: 3),
        .result(number: 4, text: answer.verdict, rating: nil),
        .result(number: 4, text: answer.verdict, rating: true),
        .branch(condition: "No Battery", verdict: "Discard all 3."),
        .web(number: 2, WebFinding(site: "bgg.com", date: "2021", role: "Designer",
                                   quote: "Yes, as long as he has boots.", warning: "⚠ Designer disagrees")),
    ]

    static let cardItems: [CardItem] = answer.steps.enumerated().map { i, s in
        CardItem(id: .step(i), content: .step(number: i + 1, title: ViewerModel.stepTitle(i, of: answer.steps.count),
                                             pages: s.evidence.map(\.page).uniqued(), text: s.text, figure: false))
    } + [CardItem(id: .result, content: .result(number: answer.steps.count + 1, text: answer.verdict, rating: nil))]

    static let stepRows: [StepRow] = answer.steps.enumerated().map {
        StepRow(index: $0, text: $1.text, pages: $1.evidence.map(\.page).uniqued())
    }

    // MARK: Model

    enum ModelState { case idle, streaming, answered, branch }

    static func model(_ state: ModelState = .answered, detent: SheetDetent = .medium) -> ViewerModel {
        let m = ViewerModel()
        m.open(rulebookURL, remember: false)
        var live = LiveAnswer(question: "what happens to my energy at end of turn if I have the battery", answer: answer)
        switch state {
        case .idle:
            return m
        case .streaming:
            live.complete = false
            live.steps = Array(live.steps.prefix(1))
            m.present(live, phase: .streaming)
        case .answered:
            m.present(live, phase: .done)
        case .branch:
            m.present(live, phase: .done)
            m.selectBranch(0)
        }
        m.detent = detent
        return m
    }
}
