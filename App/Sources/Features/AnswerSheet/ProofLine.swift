import SwiftUI
import AckshuallyCore

/// The one secondary line under the verdict: "checkmark.seal  Stated in the rules · p.3, p.4" (with several
/// books: "· Law of Root p.12, Riverfolk p.4").
struct ProofLine: View {
    var confidence: Confidence
    var pages: [PageReference]
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

    static func text(_ c: Confidence, pages: [PageReference]) -> String {
        pages.isEmpty ? c.phrase : "\(c.phrase) · \(pages.label)"
    }

    static func accessibilityText(_ c: Confidence, pages: [PageReference]) -> String {
        if pages.isEmpty { return c.phrase }
        if pages.allSatisfy({ $0.book == nil }) {
            return "\(c.phrase), page\(pages.count > 1 ? "s" : "") \(pages.map { String($0.page) }.joined(separator: ", "))"
        }
        return "\(c.phrase), \(pages.map(\.spokenLabel).joined(separator: "; "))"
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: 12) {
        ProofLine(confidence: .stated, pages: [.page(3), .page(4)])
        ProofLine(confidence: .inferred, pages: [.page(2)])
        ProofLine(confidence: .notCovered, pages: [])
        ProofLine(confidence: .stated, pages: Fixtures.bookPages)
    }
    .padding()
    .themed()
}

#Preview("AX5, dark") {
    ProofLine(confidence: .stated, pages: Fixtures.bookPages)
        .padding()
        .themeBackground(\.sheet)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
