import Foundation
import OSLog
import AckshuallyCore

/// Answer details: per-evidence match status and the raw answer, for the ⋯ → Answer Details
/// screen, "Copy JSON" and (debug builds) the Xcode console.
extension ViewerModel {
    var evidenceReports: [EvidenceReport] {
        guard let a = answer else { return [] }
        var reports: [EvidenceReport] = []
        func add(_ steps: [Step], prefix: String, section: (Int, Step) -> String) {
            for (i, s) in steps.enumerated() {
                for (j, e) in s.evidence.enumerated() {
                    reports.append(EvidenceReport(id: "\(prefix)\(i + 1).\(j + 1)", step: section(i, s), page: e.page,
                                                  quote: e.quote, box: e.box, match: highlights[Self.key(e)]?.match))
                }
            }
        }
        add(a.steps, prefix: "") { i, s in "Step \(i + 1) · \(Self.stepTitle(s, number: i + 1))" }
        for b in a.branches {
            add(b.steps, prefix: "If \(b.condition) ") { i, s in "If \(b.condition.lowercasedFirst) · \(Self.stepTitle(s, number: i + 1))" }
        }
        return reports
    }

    var answerDetails: AnswerDetailsExport? {
        guard let a = answer else { return nil }
        let final = a.verdict.map {
            Answer(restatedQuestion: a.restated ?? a.question, verdict: $0, confidence: a.confidence ?? .notCovered,
                   branches: a.branches, assumptions: a.assumptions, steps: a.steps, needsWeb: a.confidence != .stated)
        }
        let raw = turns.last { $0.question == a.question }?.rawAssistantText
        return AnswerDetailsExport(question: a.question, route: route, answer: final, rawText: raw, evidence: evidenceReports)
    }

    /// Answer Details' "Answered by" row.
    var routeLabel: String? {
        route.map { $0 == .server ? "\($0.title) · \(ServerConfig.host)" : $0.title }
    }

    /// Debug builds: the raw answer when it completes and each quote's match as it resolves.
    func logAnswer() {
        #if DEBUG
        guard let d = answerDetails else { return }
        Self.log.debug("answer: \(d.json, privacy: .public)")
        #endif
    }

    func logMatch(_ e: Evidence, _ h: Highlight) {
        #if DEBUG
        Self.log.debug("evidence p.\(e.page) \(h.match.result.rawValue, privacy: .public) [\(h.match.detail, privacy: .public)] rects=\(h.match.rects) quote=\(e.quote ?? "–", privacy: .public)")
        #endif
    }

    static let log = Logger(subsystem: "app.ackshually.viewer", category: "answer")
}
