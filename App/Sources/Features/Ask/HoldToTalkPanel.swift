import SwiftUI

/// What the ask bar shows while the mic is held (S3): live transcript, "‹ slide to cancel".
struct HoldToTalkPanel: View {
    var transcript: String
    var cancelArmed: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Text(transcript.isEmpty ? "Listening…" : "“\(transcript)”")
            .font(theme.font.field)
            .foregroundStyle(transcript.isEmpty ? theme.colors.muted : theme.colors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// "‹ slide to cancel" / "Release to cancel".
struct SlideToCancelHint: View {
    var cancelArmed: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Text(cancelArmed ? "Release to cancel" : "‹ slide to cancel")
            .font(theme.font.body)
            .foregroundStyle(cancelArmed ? theme.colors.accent : theme.colors.muted)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HoldToTalkPanel(transcript: "", cancelArmed: false)
        HoldToTalkPanel(transcript: "what happens to my energy at end of turn if I have the batt", cancelArmed: false)
        SlideToCancelHint(cancelArmed: false)
        SlideToCancelHint(cancelArmed: true)
    }
    .padding()
    .themed()
}
