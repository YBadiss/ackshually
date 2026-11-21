import SwiftUI
import AckshuallyCore

/// Fixed answer header (S4/S5): restated question · verdict · confidence · branch pills.
/// While arriving it shows the question, skeleton lines and Stop (S4).
struct AnswerHeader: View {
    var content: HeaderContent
    var onStop: () -> Void = {}
    var onBranch: (Int?) -> Void = { _ in }
    var onRetry: () -> Void = {}
    var onClose: () -> Void = {}
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch content.state {
            case .arriving: arriving
            case .answered: answered
            case .failed(let msg): FailureHeader(question: content.question, message: msg, onRetry: onRetry, onClose: onClose)
            }
        }
        .padding(.horizontal, theme.spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...theme.layout.maxHeaderTypeSize)
    }

    private var arriving: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("You asked").font(theme.font.restated).foregroundStyle(theme.colors.muted)
            Text(content.question)
                .font(theme.font.question).foregroundStyle(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, theme.spacing.xs)
            SkeletonLine(widthFraction: 0.85, isTitle: true)
            SkeletonLine(widthFraction: 0.45)
            ViewThatFits(in: .horizontal) {
                HStack { reading; Spacer(); stop }
                VStack(alignment: .leading, spacing: theme.spacing.s) { reading; stop }
            }
            .padding(.top, theme.spacing.m).padding(.bottom, theme.spacing.l)
        }
    }

    private var answered: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.question)
                    .font(theme.font.restated).foregroundStyle(theme.colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: theme.spacing.m)
                if content.isBusy { stop }
            }
            .padding(.bottom, theme.spacing.xs)
            Text(content.verdict ?? "")
                .font(theme.font.verdict).tracking(theme.font.verdictTracking)
                .foregroundStyle(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("verdict")
                .accessibilityAddTraits(.isHeader)
            FlowRow(spacing: theme.spacing.s) {
                if let c = content.confidence { ConfidenceChip(confidence: c, pages: content.pages) }
                BranchPills(branches: content.branches, active: content.activeBranch, onSelect: onBranch)
                if content.stopped { flag("Stopped") }
                if content.demo { flag("Demo answer") }
            }
            .padding(.top, theme.spacing.m).padding(.bottom, theme.spacing.l)
        }
    }

    private var reading: some View {
        Text("Reading the rulebook…").font(theme.font.body).foregroundStyle(theme.colors.muted)
    }

    private var stop: some View {
        OutlineButton(title: "Stop", systemImage: "stop.fill", action: onStop)
            .accessibilityIdentifier("stop")
    }

    private func flag(_ t: String) -> some View {
        Text(t).font(theme.font.chip).foregroundStyle(theme.colors.muted)
            .padding(.vertical, theme.spacing.xs)
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 24) {
            AnswerHeader(content: Fixtures.headerArriving)
            AnswerHeader(content: Fixtures.headerStreaming)
            AnswerHeader(content: Fixtures.headerStated)
            AnswerHeader(content: Fixtures.headerInferred)
            AnswerHeader(content: Fixtures.headerNotCovered)
            AnswerHeader(content: Fixtures.headerBranchActive)
            AnswerHeader(content: Fixtures.headerFailed)
        }
        .padding(.vertical)
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    ScrollView { AnswerHeader(content: Fixtures.headerStated) }
        .themed()
        .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    VStack { AnswerHeader(content: Fixtures.headerArriving); AnswerHeader(content: Fixtures.headerStated) }
        .themeBackground(\.sheet)
        .themed()
        .preferredColorScheme(.dark)
}
