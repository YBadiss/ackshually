import SwiftUI

/// The 🎙 button (S3). Pure: reports press / horizontal drag / release; the caller decides
/// whether that was a hold (live transcript) or a tap (dictation).
struct PushToTalkButton: View {
    var isDictating: Bool
    var isHolding: Bool
    var compact = false
    var onPress: () -> Void
    var onDrag: (CGFloat) -> Void
    var onRelease: () -> Void
    /// VoiceOver / keyboard: plain activation = tap.
    var onActivate: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        let d = compact ? theme.size.micButtonCompact : theme.size.micButton
        Image(systemName: isDictating ? "stop.fill" : "mic.fill")
            .font(theme.font.icon)
            .frame(width: d, height: d)
            .background(theme.colors.accent, in: Circle())
            .foregroundStyle(theme.colors.accentInk)
            .scaleEffect(isHolding ? 1.2 : 1)
            .animation(.snappy, value: isHolding)
            .contentShape(Circle().inset(by: -theme.spacing.m))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        onPress()
                        onDrag(v.translation.width)
                    }
                    .onEnded { _ in onRelease() }
            )
            .accessibilityElement()
            .accessibilityLabel(isDictating ? "Stop dictation" : "Microphone")
            .accessibilityHint("Hold to ask out loud, tap to dictate")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onActivate() }
            .accessibilityIdentifier("mic")
    }
}

#Preview {
    HStack(spacing: 20) {
        PushToTalkButton(isDictating: false, isHolding: false, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
        PushToTalkButton(isDictating: true, isHolding: false, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
        PushToTalkButton(isDictating: false, isHolding: true, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
        PushToTalkButton(isDictating: false, isHolding: false, compact: true, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
    }
    .padding()
    .themed()
}
