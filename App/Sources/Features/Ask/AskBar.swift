import SwiftUI

/// S3 ask field: type and send (always available), hold 🎙 = live transcript (release sends,
/// slide left cancels), tap 🎙 = dictation into the field. `compact` = follow-up field in the sheet.
struct AskBar: View {
    @Binding var text: String
    var voice: AskController
    var placeholder = "Ask about the rules…"
    var compact = false
    var onSend: (String) -> Void
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool
    @State private var width: CGFloat = 0

    private var holding: Bool { voice.mode == .holding }
    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            if holding { HoldToTalkPanel(transcript: voice.transcript, cancelArmed: voice.cancelArmed) }
            // The mic keeps one identity across modes so a hold gesture isn't interrupted.
            HStack(spacing: theme.spacing.m) {
                if holding {
                    SlideToCancelHint(cancelArmed: voice.cancelArmed)
                    Spacer()
                    Waveform(level: voice.level)
                } else {
                    field
                    if voice.mode == .dictating { Waveform(level: voice.level) }
                }
                if hasText, voice.mode == .idle { sendButton } else { mic }
            }
            if let e = voice.error {
                Text(e).font(theme.font.meta).foregroundStyle(theme.colors.warning)
            }
        }
        .padding(.leading, theme.spacing.l).padding(.trailing, theme.spacing.s)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .background(compact ? theme.colors.background : theme.colors.card,
                    in: RoundedRectangle(cornerRadius: holding ? theme.radius.sheet : theme.radius.field))
        .shadow(color: theme.colors.line, radius: 0, y: compact ? 0 : theme.size.hairline)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: voice.transcript) { _, _ in if let t = voice.dictatedText() { text = t } }
        .onChange(of: voice.speech.isRecording) { _, rec in if !rec { voice.recordingStopped() } }
    }

    private var field: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(1...4)
            .font(compact ? theme.font.fieldCompact : theme.font.field)
            .foregroundStyle(theme.colors.ink)
            .tint(theme.colors.accent)
            .focused($focused)
            .submitLabel(.send)
            .onSubmit(send)
            .accessibilityIdentifier(compact ? "followUpField" : "askField")
    }

    private var mic: some View {
        PushToTalkButton(
            isDictating: voice.mode == .dictating, isHolding: holding, compact: compact,
            onPress: {
                if voice.mode == .idle { focused = false }
                voice.pressBegan(holdDelay: theme.layout.holdToTalkDelay)
            },
            onDrag: { voice.dragChanged(dx: $0, cancelThreshold: width * theme.layout.slideToCancelFraction) },
            onRelease: {
                if let said = voice.pressEnded(currentText: text) { onSend(said) }
                if voice.mode == .idle, hasText { focused = true }
            },
            onActivate: { voice.toggleDictation(currentText: text) })
    }

    private var sendButton: some View {
        let d = compact ? theme.size.micButtonCompact : theme.size.micButton
        return Button(action: send) {
            Image(systemName: "arrow.up")
                .font(theme.font.icon)
                .frame(width: d, height: d)
                .background(theme.colors.accent, in: Circle())
                .foregroundStyle(theme.colors.accentInk)
        }
        .accessibilityLabel("Send")
        .accessibilityIdentifier("send")
    }

    private func send() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        voice.stopDictation()
        focused = false
        onSend(q)
    }
}

private struct AskBarPreview: View {
    @State var text: String
    var compact = false
    @State var voice = AskController()
    var body: some View {
        AskBar(text: $text, voice: voice, compact: compact) { _ in }
    }
}

#Preview("States") {
    VStack(spacing: 16) {
        AskBarPreview(text: "")
        AskBarPreview(text: "Can I keep unused energy with a Battery?")
        AskBarPreview(text: "", compact: true)
    }
    .padding()
    .themeBackground(\.background)
    .themed()
}

#Preview("AX5") {
    AskBarPreview(text: "Can I keep unused energy with a Battery?")
        .padding()
        .themeBackground(\.background)
        .themed()
        .dynamicTypeSize(.accessibility5)
}
