import SwiftUI
import AckshuallyCore

/// "✓ Stated · p.12, p.14" / "≈ Inferred · p.8" / "? Not covered" (spec §3 voice).
/// `short` drops the label: "✓ p.14" (collapsed sheet, S7).
struct ConfidenceChip: View {
    var confidence: Confidence
    var pages: [Int]
    var short = false
    @Environment(\.theme) private var theme

    var body: some View {
        Text(Self.text(confidence, pages: pages, short: short))
            .font(theme.font.chip)
            .padding(.horizontal, theme.spacing.m).padding(.vertical, theme.spacing.xs)
            .foregroundStyle(confidence == .stated ? theme.colors.stated : theme.colors.warning)
            .background(confidence == .stated ? theme.colors.statedBG : theme.colors.warningBG,
                        in: RoundedRectangle(cornerRadius: theme.radius.label))
            .accessibilityLabel("\(confidence.label)\(pages.isEmpty ? "" : ", pages \(pages.map(String.init).joined(separator: ", "))")")
    }

    static func text(_ c: Confidence, pages: [Int], short: Bool) -> String {
        let p = pages.map { "p.\($0)" }.joined(separator: ", ")
        if pages.isEmpty { return "\(c.symbol) \(c.label)" }
        return short ? "\(c.symbol) \(p)" : "\(c.symbol) \(c.label) · \(p)"
    }
}

extension Confidence {
    var symbol: String {
        switch self {
        case .stated: "✓"
        case .inferred: "≈"
        case .notCovered: "?"
        }
    }

    var label: String {
        switch self {
        case .stated: "Stated"
        case .inferred: "Inferred"
        case .notCovered: "Not covered"
        }
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: 8) {
        ConfidenceChip(confidence: .stated, pages: [3, 4])
        ConfidenceChip(confidence: .inferred, pages: [2])
        ConfidenceChip(confidence: .notCovered, pages: [])
        ConfidenceChip(confidence: .stated, pages: [4], short: true)
    }
    .padding()
    .themed()
}

#Preview("AX5") {
    ConfidenceChip(confidence: .stated, pages: [3, 4])
        .padding()
        .themed()
        .dynamicTypeSize(.accessibility5)
}
