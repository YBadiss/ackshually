import Foundation
import AckshuallyCore

/// One cited passage of the shown answer and how it was placed (Answer details, S-debug).
struct EvidenceReport: Identifiable, Equatable, Encodable {
    /// "1.1" = step 1, evidence 1; "If no Battery 1.1" for a branch step.
    var id: String
    /// Section title: "Step 1 · Picking is mandatory".
    var step: String
    /// Page of the sent document (the joined one with several books).
    var page: Int
    /// Several books: that page in its own book ("Solar Expansion p.2"). nil with one book.
    var book: PageReference? = nil
    var quote: String?
    var box: NormalizedBox?
    /// nil while the matcher is still running.
    var match: MatchInfo?
}

extension EvidenceReport {
    /// Every cited passage of `answer` (main steps, then each branch's) with how it was placed.
    @MainActor
    static func reports(for answer: LiveAnswer, highlights: HighlightStore, contents: RulebookContents? = nil) -> [EvidenceReport] {
        var reports: [EvidenceReport] = []
        func add(_ steps: [Step], prefix: String, section: (Int, Step) -> String) {
            for (i, s) in steps.enumerated() {
                for (j, e) in s.evidence.enumerated() {
                    let book = contents.flatMap { $0.isJoined ? $0.reference(for: e.page) : nil }
                    reports.append(EvidenceReport(id: "\(prefix)\(i + 1).\(j + 1)", step: section(i, s), page: e.page, book: book,
                                                  quote: e.quote, box: e.box, match: highlights[e]?.match))
                }
            }
        }
        add(answer.steps, prefix: "") { i, s in "Step \(i + 1) · \(s.displayTitle(number: i + 1))" }
        for b in answer.branches {
            add(b.steps, prefix: "If \(b.condition) ") { i, s in "If \(b.condition.lowercasedFirst) · \(s.displayTitle(number: i + 1))" }
        }
        return reports
    }

    /// "p.12", or "Solar Expansion p.2" with several books.
    var location: String { book?.label ?? "p.\(page)" }

    /// Consecutive reports of the same step, in order (one list section per step).
    static func sections(_ reports: [EvidenceReport]) -> [(title: String, rows: [EvidenceReport])] {
        var out: [(title: String, rows: [EvidenceReport])] = []
        for r in reports {
            if out.last?.title == r.step { out[out.count - 1].rows.append(r) } else { out.append((r.step, [r])) }
        }
        return out
    }
}
