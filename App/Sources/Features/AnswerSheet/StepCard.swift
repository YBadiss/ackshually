import SwiftUI

/// One card of the carousel (S5/S6): number · title · page, then one or two sentences.
/// Also renders the loading placeholder, the last "Result" card (with 👍/👎), a branch card and
/// (M4) a bordered web-finding card.
struct StepCard: View {
    var content: StepCardContent
    var isCurrent = true
    var onRate: (Bool) -> Void = { _ in }
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            switch content {
            case let .step(n, title, pages, text, figure):
                CardTitle(leading: "\(n) · \(title)", trailing: Self.pageText(pages))
                Text(text).font(theme.font.body).foregroundStyle(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if figure {
                    Label("Figure", systemImage: "photo").font(theme.font.meta).foregroundStyle(theme.colors.muted)
                }
            case .loading(let n):
                CardTitle(leading: "\(n) · Reading…", trailing: nil)
                SkeletonLine(widthFraction: 0.9)
                SkeletonLine(widthFraction: 0.6)
            case let .result(n, text, rating):
                CardTitle(leading: "\(n) · Result", trailing: nil)
                Text(text).font(theme.font.bodyStrong).foregroundStyle(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                FeedbackButtons(rating: rating, onRate: onRate).padding(.top, theme.spacing.xs)
            case let .branch(condition, verdict):
                CardTitle(leading: "If · \(condition)", trailing: nil)
                Text(verdict).font(theme.font.bodyStrong).foregroundStyle(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The rulebook steps are on the main answer.")
                    .font(theme.font.meta).foregroundStyle(theme.colors.muted)
            case let .web(n, w):
                if let warn = w.warning {
                    Text(warn).font(theme.font.cardTitle).foregroundStyle(theme.colors.warning)
                }
                CardTitle(leading: "\(n) · 🌐 \(w.site) · \(w.date)", trailing: "↗")
                Text("“\(w.quote)”").font(theme.font.body).foregroundStyle(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(w.role).font(theme.font.meta).foregroundStyle(theme.colors.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: theme.size.cardMinHeight, alignment: .topLeading)
        .padding(.horizontal, theme.spacing.l).padding(.vertical, theme.spacing.m)
        .background(theme.colors.card, in: RoundedRectangle(cornerRadius: theme.radius.card))
        .overlay {
            if case .web = content {
                RoundedRectangle(cornerRadius: theme.radius.card).strokeBorder(theme.colors.line, lineWidth: theme.size.hairline)
            }
        }
        .shadow(color: theme.colors.line, radius: 0, y: theme.size.hairline)
        .opacity(isCurrent ? 1 : 0.6)
        .animation(.easeOut(duration: 0.2), value: isCurrent)
        .accessibilityElement(children: .contain)
    }

    static func pageText(_ pages: [Int]) -> String? {
        pages.isEmpty ? nil : pages.map { "p.\($0)" }.joined(separator: ", ")
    }
}

/// "1 · Rule ……… p.3"
struct CardTitle: View {
    var leading: String
    var trailing: String?
    @Environment(\.theme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: theme.spacing.s)
                pages
            }
            VStack(alignment: .leading, spacing: theme.spacing.xxs) { title; pages }
        }
    }

    private var title: some View {
        Text(leading).font(theme.font.cardTitle).foregroundStyle(theme.colors.ink)
    }

    @ViewBuilder private var pages: some View {
        if let trailing { Text(trailing).font(theme.font.meta).foregroundStyle(theme.colors.muted) }
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(Array(Fixtures.cardStates.enumerated()), id: \.offset) { _, c in StepCard(content: c) }
            StepCard(content: Fixtures.cardStates[0], isCurrent: false)
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
        StepCard(content: Fixtures.cardStates[5])
    }
    .padding()
    .themeBackground(\.sheet)
    .themed()
    .preferredColorScheme(.dark)
}
