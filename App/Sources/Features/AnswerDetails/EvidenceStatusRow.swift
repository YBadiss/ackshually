import SwiftUI

/// One cited passage: page, match status, the quote (or the figure box).
struct EvidenceStatusRow: View {
    var report: EvidenceReport
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label(statusText, systemImage: symbol)
                    .foregroundStyle(color)
                    .font(theme.font.rowValue.weight(.semibold))
                Spacer(minLength: theme.spacing.s)
                Text(report.location).font(theme.font.rowValue.monospacedDigit()).foregroundStyle(theme.colors.secondaryLabel)
            }
            if let q = report.quote, !q.isEmpty {
                Text("“\(q)”").font(theme.font.rowValue).foregroundStyle(theme.colors.label)
                    .textSelection(.enabled)
            }
            if let b = report.box {
                Text("Box x \(b.x, format: .number.precision(.fractionLength(2))) y \(b.y, format: .number.precision(.fractionLength(2))) w \(b.w, format: .number.precision(.fractionLength(2))) h \(b.h, format: .number.precision(.fractionLength(2)))")
                    .font(theme.font.footnote.monospacedDigit()).foregroundStyle(theme.colors.secondaryLabel)
            }
            if let m = report.match {
                Text(m.detail).font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("evidence-\(report.id)")
    }

    private var statusText: String {
        guard let m = report.match else { return "Matching…" }
        switch m.result {
        case .matched: return m.layout == .fragments ? "Matched in \(m.fragments) pieces" : "Matched"
        case .matchedOtherPage: return "Matched on p.\(m.matchedPage ?? report.page)" + (m.layout == .fragments ? ", in \(m.fragments) pieces" : "")
        case .partial: return "Partly matched · \(m.coverage.formatted(.percent.precision(.fractionLength(0))))"
        case .matchedNotLocated: return "Matched, not located"
        case .notMatched: return "Not matched"
        case .figureBox: return "Figure box"
        case .figureNoBox: return "Figure, no usable box"
        }
    }

    private var symbol: String {
        guard let m = report.match else { return "hourglass" }
        if m.result == .partial { return "circle.lefthalf.filled" }
        return m.isSpotlit ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var color: Color {
        guard let m = report.match else { return theme.colors.secondaryLabel }
        if m.result == .partial { return theme.colors.inferred }
        return m.isSpotlit ? theme.colors.stated : theme.colors.inferred
    }
}

#Preview {
    List {
        ForEach(Fixtures.evidenceReports) { EvidenceStatusRow(report: $0) }
    }
    .themed()
}

#Preview("AX5, dark") {
    List {
        ForEach(Fixtures.evidenceReports) { EvidenceStatusRow(report: $0) }
    }
    .themed()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
