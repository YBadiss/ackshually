import SwiftUI

/// One card of the carousel (S5/S6), styled as a system shelf card (App Store / Music):
/// rounded, no border or shadow. Caption = step title + page, then one or two sentences.
/// Also renders the loading placeholder, the last "Result" card (with thumbs), a branch
/// without steps and (M4) a web-finding card.
struct StepCard: View {
    var content: StepCardContent
    var onRate: (Bool) -> Void = { _ in }
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            switch content {
            case let .step(_, title, pages, text, figure):
                CardCaption(title: title, trailing: Self.pageText(pages))
                body(text)
                if figure {
                    Label("Figure on this page", systemImage: "photo")
                        .font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel)
                }
            case .loading:
                CardCaption(title: "Reading…", trailing: nil)
                body("Unused energy is discarded at the end of your turn, as the rules say.")
                    .redacted(reason: .placeholder)
            case let .result(_, text, rating):
                CardCaption(title: "Result", trailing: nil)
                Text(text).font(theme.font.cardStrong).foregroundStyle(theme.colors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: theme.spacing.xs)
                FeedbackButtons(rating: rating, onRate: onRate)
            case let .branch(condition, verdict):
                CardCaption(title: "If \(condition.lowercasedFirst)", trailing: nil)
                Text(verdict).font(theme.font.cardStrong).foregroundStyle(theme.colors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No rulebook passage for this case.")
                    .font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel)
            case let .web(_, w):
                if let warn = w.warning {
                    Label(warn, systemImage: "exclamationmark.triangle.fill")
                        .font(theme.font.cardCaption).foregroundStyle(theme.colors.warning)
                }
                CardCaption(title: "\(w.site) · \(w.date)", trailing: nil, systemImage: "globe")
                body("“\(w.quote)”")
                Text(w.role).font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, minHeight: theme.size.cardMinHeight, alignment: .topLeading)
        .padding(.horizontal, theme.spacing.xl).padding(.vertical, theme.spacing.l)
        .background(theme.colors.card, in: .rect(cornerRadius: theme.radius.card))
        .accessibilityElement(children: .contain)
    }

    private func body(_ text: String) -> some View {
        Text(text).font(theme.font.cardBody).foregroundStyle(theme.colors.label)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func pageText(_ pages: [Int]) -> String? {
        pages.isEmpty ? nil : pages.map { "p.\($0)" }.joined(separator: ", ")
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(Array(Fixtures.cardStates.enumerated()), id: \.offset) { _, c in StepCard(content: c) }
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    ScrollView {
        VStack(spacing: 12) {
            StepCard(content: Fixtures.cardStates[0])
            StepCard(content: Fixtures.cardStates[3])
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
    .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    VStack(spacing: 12) {
        StepCard(content: Fixtures.cardStates[0])
        StepCard(content: Fixtures.cardStates[4])
    }
    .padding()
    .themeBackground(\.sheet)
    .themed()
    .preferredColorScheme(.dark)
}
