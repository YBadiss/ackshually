import SwiftUI
import AckshuallyCore

/// Answer header (S4/S5): bold verdict, then one proof line. Text hierarchy, no chips.
/// The restated question shows only while arriving and when `showsQuestion` (expanded / inspector);
/// otherwise the verdict is capped at `layout.verdictMaxLines`.
/// Trailing: Stop while streaming, otherwise the standard close button.
struct AnswerHeader: View {
    var content: HeaderContent
    var showsQuestion = false
    var onStop: () -> Void = {}
    var onRetry: () -> Void = {}
    /// Open Settings: offered only when the failure is fixed there (rejected credential).
    var onSettings: (() -> Void)?
    var onClose: () -> Void = {}
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.l) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                switch content.state {
                case .arriving: arriving
                case .answered: answered
                case .failed(let f): FailureHeader(message: f.message, onRetry: onRetry, onSettings: f.opensSettings ? onSettings : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingButton
        }
        .dynamicTypeSize(...theme.layout.maxHeaderTypeSize)
    }

    private var question: some View {
        Text(content.question)
            .font(theme.font.question)
            .foregroundStyle(theme.colors.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("You asked: \(content.question)")
    }

    @ViewBuilder private var arriving: some View {
        question
        // Native placeholders (redacted text) for the verdict and proof line on their way.
        Group {
            Text("Keep 2 energy on the Battery, discard 1.").font(theme.font.verdict)
            Text("Stated in the rules · p.3").font(theme.font.proof)
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var answered: some View {
        if showsQuestion { question.padding(.bottom, theme.spacing.xxs) }
        if let condition = content.condition {
            Label("If \(condition.lowercasedFirst)", systemImage: "arrow.triangle.branch")
                .font(theme.font.footnote.weight(.semibold))
                .foregroundStyle(theme.colors.tint)
        }
        Text(content.verdict ?? "")
            .font(theme.font.verdict)
            .foregroundStyle(theme.colors.label)
            // At most 3 lines on the sheet's smaller detents; the full verdict when expanded.
            .lineLimit(showsQuestion ? nil : theme.layout.verdictMaxLines)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(content.verdict ?? "")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("verdict")
        if let c = content.confidence {
            ProofLine(confidence: c, pages: content.pages)
        }
        if content.stopped {
            Text("Stopped before the end").font(theme.font.footnote).foregroundStyle(theme.colors.secondaryLabel)
        }
    }

    @ViewBuilder private var trailingButton: some View {
        if content.isBusy {
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityIdentifier("stop")
        } else {
            Button(role: .close, action: onClose) {
                Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
            }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityIdentifier("closeAnswer")
        }
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 28) {
            AnswerHeader(content: Fixtures.headerArriving)
            AnswerHeader(content: Fixtures.headerStreaming)
            AnswerHeader(content: Fixtures.headerStated)
            AnswerHeader(content: Fixtures.headerStated, showsQuestion: true)
            AnswerHeader(content: Fixtures.headerInferred)
            AnswerHeader(content: Fixtures.headerNotCovered)
            AnswerHeader(content: Fixtures.headerBranchActive)
            AnswerHeader(content: Fixtures.headerLongVerdict)
            AnswerHeader(content: Fixtures.headerLongVerdict, showsQuestion: true)
            AnswerHeader(content: Fixtures.headerFailed)
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    ScrollView { AnswerHeader(content: Fixtures.headerStated, showsQuestion: true).padding() }
        .themeBackground(\.sheet)
        .themed()
        .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    VStack(spacing: 28) {
        AnswerHeader(content: Fixtures.headerArriving)
        AnswerHeader(content: Fixtures.headerStated)
    }
    .padding()
    .themeBackground(\.sheet)
    .themed()
    .preferredColorScheme(.dark)
}
