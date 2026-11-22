import SwiftUI
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

    /// Something page-like behind floating glass controls in previews.
    static var pageBackdrop: some View {
        LinearGradient(colors: [Color(white: 0.98), Color(red: 0.95, green: 0.9, blue: 0.8)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: Header states

    static let headerArriving = HeaderContent(state: .arriving, question: answer.restatedQuestion, isBusy: true)
    static let headerStreaming = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: answer.verdict,
                                               confidence: .stated, pages: [3], isBusy: true)
    static let headerStated = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: answer.verdict,
                                            confidence: .stated, pages: [3, 4])
    static let headerInferred = HeaderContent(state: .answered, question: "Can I trade energy for coins with another player?",
                                              verdict: "No: energy can't be traded at all, so not for coins either.",
                                              confidence: .inferred, pages: [3])
    static let headerNotCovered = HeaderContent(state: .answered, question: "Can a Windmill be sold back?",
                                                verdict: "Probably not; the rules don't mention selling plants.",
                                                confidence: .notCovered, pages: [])
    static let headerBranchActive = HeaderContent(state: .answered, question: answer.restatedQuestion, verdict: "Discard all 3.",
                                                  confidence: .stated, pages: [3], condition: "Without a Battery")
    /// Longer than the 3-line cap (old prompts produced verdicts like this).
    static let headerLongVerdict = HeaderContent(state: .answered, question: "If I can't place any color, what do I do?",
                                                 verdict: "You still must pick tiles, and any you can't or don't want to place go to your floor line, costing you minus points. Taking is not optional, and the starting player marker counts as a floor tile too.",
                                                 confidence: .inferred, pages: [3, 4, 5])
    // MARK: Settings

    static let routeBundled = RouteStatus(active: .bundledToken, serverHost: "ackshually.badyass.xyz")
    static let routeOverride = RouteStatus(active: .tokenOverride, serverHost: "ackshually.badyass.xyz", tokenOverrideSaved: true)
    static let routeAPIKey = RouteStatus(active: .apiKey(fromEnvironment: false), serverHost: "ackshually.badyass.xyz", apiKeySaved: true)
    static let routeNone = RouteStatus(active: .none, serverHost: "ackshually.badyass.xyz")

    static let tokenRejected = "The server didn't accept your access token. It may be mistyped or revoked: check it in Settings."
    static let dailyLimit = "Today's question limit is reached. Try again tomorrow."
    static let headerFailed = HeaderContent(state: .failed(tokenRejected),
                                            question: "Can I keep energy?")

    // MARK: Cards

    static let cardStates: [StepCardContent] = [
        .step(number: 1, title: "General rule", pages: [3], text: answer.steps[0].text, figure: false),
        .step(number: 2, title: "Scoring track", pages: [4], text: "The scoring track shows 1 point per 3 energy spent.", figure: true),
        .loading(number: 3),
        .step(number: 3, title: "Long step", pages: [4], text: longStepText, figure: false),
        .branch(condition: "No Battery", verdict: "Discard all 3."),
        .web(number: 2, WebFinding(site: "bgg.com", date: "2021", role: "Designer",
                                   quote: "Yes, as long as he has boots.", warning: "Designer disagrees")),
    ]

    static let cardItems: [CardItem] = answer.steps.enumerated().map { i, s in
        CardItem(id: .step(i), content: ViewerModel.card(s, number: i + 1))
    } + [CardItem(id: .step(answer.steps.count), content: cardStates[3])]

    /// More than a card's line limit at any size: the card truncates and shows "More".
    static let longStepText = "A player who owns a Battery keeps up to 2 unused energy at the end of the turn instead of discarding them. "
        + "Any additional energy is discarded as normal, and energy kept this way can be spent on the next turn like any other energy. "
        + "The Battery does not produce energy itself, and keeping energy is optional: you may still discard it."

    static let evidenceReports: [EvidenceReport] = [
        EvidenceReport(id: "1.1", step: "Step 1 · General rule", page: 3, quote: "you must discard all unused energy",
                       match: MatchInfo(result: .matched, detail: "matched", matchedPage: 3, errorRate: 0, geometryScore: 0.91, rects: 1)),
        EvidenceReport(id: "2.1", step: "Step 2 · Battery exception", page: 4, quote: "keeps up to 2 unused energy",
                       match: MatchInfo(result: .matchedOtherPage, detail: "matched on p.4 (claimed p.3)", matchedPage: 4, rects: 1)),
        EvidenceReport(id: "2.3", step: "Step 2 · Battery exception", page: 15, quote: "Spend two supporters matching a sympathetic clearing. Remove all enemy pieces there and place the matching base.",
                       match: MatchInfo(result: .matched, detail: "matched (2 fragments, 100% of the quote)", matchedPage: 15, errorRate: 0,
                                        geometryScore: 0.85, rects: 2, layout: .fragments, coverage: 1, fragments: 2)),
        EvidenceReport(id: "2.4", step: "Step 2 · Battery exception", page: 3, quote: "At the end of your turn you must discard all unused energy, and players may then trade it freely.",
                       match: MatchInfo(result: .partial, detail: "partial match (52% of the quote)", matchedPage: 3, errorRate: 0.48,
                                        geometryScore: 0.95, rects: 2, layout: .partial, coverage: 0.52, fragments: 1)),
        EvidenceReport(id: "2.2", step: "Step 2 · Battery exception", page: 4, quote: "They do rule this clearing, so they can move here.",
                       match: MatchInfo(result: .notMatched, detail: "not matched (best error 44%)", errorRate: 0.44)),
        EvidenceReport(id: "3.1", step: "Step 3 · Scoring track", page: 4, quote: nil,
                       box: NormalizedBox(x: 0.15, y: 0.55, w: 0.7, h: 0.3), match: MatchInfo(result: .figureBox, detail: "figure box", rects: 1)),
        EvidenceReport(id: "3.2", step: "Step 3 · Scoring track", page: 2, quote: "Players take turns in clockwise order", match: nil),
    ]

    static let stepRows: [StepRow] = answer.steps.enumerated().map {
        StepRow(index: $0, title: ViewerModel.stepTitle($1, number: $0 + 1), text: $1.text, pages: $1.evidence.map(\.page).uniqued())
    }

    static func branchRows(active: Int?) -> [BranchRow] {
        branches.enumerated().map { BranchRow(index: $0, condition: $1.condition, verdict: $1.verdict, isActive: active == $0) }
    }

    // MARK: Model

    enum ModelState { case idle, streaming, answered, branch }

    static func model(_ state: ModelState = .answered, detent: SheetDetent = .medium) -> ViewerModel {
        let m = ViewerModel()
        m.open(rulebookURL)
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
