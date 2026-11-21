import SwiftUI
import AckshuallyCore

/// The one secondary line under the verdict: "checkmark.seal  Stated in the rules · p.3, p.4".
struct ProofLine: View {
    var confidence: Confidence
    var pages: [Int]
    @Environment(\.theme) private var theme

    var body: some View {
        Label {
            Text(Self.text(confidence, pages: pages))
        } icon: {
            Image(systemName: confidence.symbol).foregroundStyle(color)
        }
        .font(theme.font.proof)
        .foregroundStyle(theme.colors.secondaryLabel)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityText(confidence, pages: pages))
        .accessibilityIdentifier("proofLine")
    }

    private var color: Color {
        switch confidence {
        case .stated: theme.colors.stated
        case .inferred: theme.colors.inferred
        case .notCovered: theme.colors.notCovered
        }
    }

    static func text(_ c: Confidence, pages: [Int]) -> String {
        let p = pages.map { "p.\($0)" }.joined(separator: ", ")
        return pages.isEmpty ? c.phrase : "\(c.phrase) · \(p)"
    }

    static func accessibilityText(_ c: Confidence, pages: [Int]) -> String {
        pages.isEmpty ? c.phrase : "\(c.phrase), page\(pages.count > 1 ? "s" : "") \(pages.map(String.init).joined(separator: ", "))"
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: 12) {
        ProofLine(confidence: .stated, pages: [3, 4])
        ProofLine(confidence: .inferred, pages: [2])
        ProofLine(confidence: .notCovered, pages: [])
    }
    .padding()
    .themed()
}

#Preview("AX5, dark") {
    ProofLine(confidence: .stated, pages: [3, 4])
        .padding()
        .themeBackground(\.sheet)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
