import SwiftUI

/// The mic in the ask field (S3). Pure: reports press / horizontal drag / release; the caller
/// decides whether that was a hold (live transcript) or a tap (dictation).
struct PushToTalkButton: View {
    var isDictating: Bool
    var isHolding: Bool
    var onPress: () -> Void
    var onDrag: (CGFloat) -> Void
    var onRelease: () -> Void
    /// VoiceOver / keyboard: plain activation = tap.
    var onActivate: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: isDictating ? "stop.circle.fill" : (isHolding ? "mic.fill" : "mic"))
            .font(.title3)
            .foregroundStyle(isDictating || isHolding ? theme.colors.tint : theme.colors.secondaryLabel)
            .symbolEffect(.pulse, isActive: isHolding)
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isHolding ? 1.25 : 1)
            .animation(.snappy, value: isHolding)
            .frame(minWidth: theme.size.minTapTarget, minHeight: theme.size.minTapTarget)
            .contentShape(.rect)
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
    HStack(spacing: 24) {
        PushToTalkButton(isDictating: false, isHolding: false, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
        PushToTalkButton(isDictating: true, isHolding: false, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
        PushToTalkButton(isDictating: false, isHolding: true, onPress: {}, onDrag: { _ in }, onRelease: {}, onActivate: {})
    }
    .padding()
    .themed()
}
