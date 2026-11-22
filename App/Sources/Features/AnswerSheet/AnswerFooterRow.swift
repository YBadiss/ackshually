import SwiftUI

/// Under the shelf (sheet below the large detent): the follow-up field and thumbs up/down, in their
/// own row instead of inside a closing card. Stacks at accessibility text sizes.
struct AnswerFooterRow: View {
    @Binding var draft: String
    var voice: AskController
    var rating: Bool?
    var onRate: (Bool) -> Void
    var onSend: (String) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.s))
            : AnyLayout(HStackLayout(spacing: theme.spacing.s))
        layout {
            AskField(text: $draft, voice: voice, placeholder: "Ask a follow-up", style: .inline, onSend: onSend)
            FeedbackButtons(rating: rating, onRate: onRate)
                .fixedSize()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("answerFooter")
    }
}

private struct FooterPreview: View {
    @State private var draft = ""
    var rating: Bool?
    var body: some View {
        AnswerFooterRow(draft: $draft, voice: AskController(), rating: rating, onRate: { _ in }, onSend: { _ in })
    }
}

#Preview("Unrated, rated") {
    VStack(spacing: 24) { FooterPreview(); FooterPreview(rating: true) }
        .padding().themeBackground(\.sheet).themed()
}
#Preview("AX5, dark") {
    FooterPreview(rating: false)
        .padding().themeBackground(\.sheet).themed()
        .dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
