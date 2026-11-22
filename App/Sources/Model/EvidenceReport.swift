import Foundation
import AckshuallyCore

/// One cited passage of the shown answer and how it was placed (Answer details, S-debug).
struct EvidenceReport: Identifiable, Equatable, Encodable {
    /// "1.1" = step 1, evidence 1; "If no Battery 1.1" for a branch step.
    var id: String
    /// Section title: "Step 1 · Picking is mandatory".
    var step: String
    var page: Int
    var quote: String?
    var box: NormalizedBox?
    /// nil while the matcher is still running.
    var match: MatchInfo?
}

extension EvidenceReport {
    /// Consecutive reports of the same step, in order (one list section per step).
    static func sections(_ reports: [EvidenceReport]) -> [(title: String, rows: [EvidenceReport])] {
        var out: [(title: String, rows: [EvidenceReport])] = []
        for r in reports {
            if out.last?.title == r.step { out[out.count - 1].rows.append(r) } else { out.append((r.step, [r])) }
        }
        return out
    }
}
