import SwiftUI

/// "Follow-up" section at the end of the expanded answer / inspector.
struct FollowUpSection: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("FOLLOW-UP")
                .font(theme.font.sectionHeader)
                .foregroundStyle(theme.colors.secondaryLabel)
                .padding(.horizontal, theme.spacing.xl)
                .accessibilityAddTraits(.isHeader)
            AskField(text: $model.draft, voice: voice, placeholder: "Ask a follow-up", style: .inline, onSend: model.ask)
        }
    }
}

#Preview {
    FollowUpSection(model: Fixtures.model(), voice: AskController())
        .padding().themeBackground(\.sheet).themed()
}
