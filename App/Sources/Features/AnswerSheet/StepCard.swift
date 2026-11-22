import SwiftUI

/// One card of the carousel (S5/S6), styled as a system shelf card (App Store / Music):
/// rounded, no border or shadow. Caption = step title + page, then the step text, capped at
/// `layout.cardMaxLines` with "More" when longer. Also renders the loading placeholder, a branch
/// without steps and (M4) a web-finding card. The carousel gives every card the same height
/// (`height`, the tallest card's content) and reads each card's own height via `onContentHeight`.
struct StepCard: View {
    var content: StepCardContent
    /// Shared shelf height; nil = the card's own.
    var height: CGFloat?
    var onMore: () -> Void = {}
    var onContentHeight: (CGFloat) -> Void = { _ in }
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
                LoadingCardBody()
            case let .branch(condition, verdict):
                CardCaption(title: "If \(condition.lowercasedFirst)", trailing: nil)
                body(verdict, font: theme.font.cardStrong)
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
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onContentHeight($0) }
        .frame(maxWidth: .infinity, minHeight: max(height ?? 0, theme.size.cardMinHeight), alignment: .topLeading)
        .padding(.horizontal, theme.spacing.xl).padding(.vertical, theme.spacing.l)
        .background(theme.colors.card, in: .rect(cornerRadius: theme.radius.card))
        .accessibilityElement(children: .contain)
    }

    private func body(_ text: String, font: Font? = nil) -> some View {
        TruncatingText(text: text, lineLimit: theme.layout.cardMaxLines, font: font ?? theme.font.cardBody, onMore: onMore)
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
