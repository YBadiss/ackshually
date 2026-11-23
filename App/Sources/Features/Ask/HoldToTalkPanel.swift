import SwiftUI

/// What the ask bar shows while the mic is held (S3): live transcript, "‹ slide to cancel".
struct HoldToTalkPanel: View {
    var transcript: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(transcript.isEmpty ? "Listening…" : "“\(transcript)”")
            .font(theme.font.field)
            .foregroundStyle(transcript.isEmpty ? theme.colors.secondaryLabel : theme.colors.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HoldToTalkPanel(transcript: "")
        HoldToTalkPanel(transcript: "what happens to my energy at end of turn if I have the batt")
        SlideToCancelHint(cancelArmed: false)
        SlideToCancelHint(cancelArmed: true)
    }
    .padding()
    .themed()
}
