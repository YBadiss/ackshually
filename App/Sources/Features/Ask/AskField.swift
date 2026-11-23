import SwiftUI

/// S3 ask field: type and send (always available), hold the mic = live transcript (release
/// sends, slide left cancels), tap the mic = dictation into the field.
/// - `.floating`: the bottom field over the PDF, Liquid Glass (like the iOS 26 bottom search field).
/// - `.inline`: the follow-up field on the answer sheet (filled, no glass on the sheet).
struct AskField: View {
    enum Style { case floating, inline }

    @Binding var text: String
    var voice: AskController
    var placeholder = "Ask about the rules"
    var style: Style = .floating
    var onSend: (String) -> Void
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool
    @State private var width: CGFloat = 0

    private var holding: Bool { voice.mode == .holding }
    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            if holding { HoldToTalkPanel(transcript: voice.transcript) }
            // The mic keeps one identity across modes so a hold gesture isn't interrupted.
            HStack(alignment: .center, spacing: theme.spacing.m) {
                if holding {
                    SlideToCancelHint(cancelArmed: voice.cancelArmed)
                    Spacer()
                    Waveform(level: voice.level)
                } else {
                    Image(systemName: style == .floating ? "magnifyingglass" : "text.bubble")
                        .foregroundStyle(theme.colors.secondaryLabel)
                        .accessibilityHidden(true)
                    field
                    if voice.mode == .dictating { Waveform(level: voice.level) }
                }
                if hasText, voice.mode == .idle { sendButton } else { mic }
            }
            if let e = voice.error {
                Text(e).font(theme.font.footnote).foregroundStyle(theme.colors.warning)
            }
        }
        .font(theme.font.field)
        .padding(.leading, theme.spacing.l).padding(.trailing, theme.spacing.xs)
        .padding(.vertical, theme.spacing.xxs)
        .modifier(AskFieldBackground(style: style, expanded: holding))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: text) { _, t in
            // Vertical text fields insert Return as a newline instead of submitting. Send the
            // cleaned text without writing it back first: two writes in one frame made SwiftUI
            // log "onChange(of: String) action tried to update multiple times per frame".
            guard t.contains("\n") else { return }
            let cleaned = t.replacingOccurrences(of: "\n", with: " ")
            if !submit(cleaned) { text = cleaned }
        }
        .onChange(of: voice.transcript) { _, _ in if let t = voice.dictatedText() { text = t } }
        .onChange(of: voice.speech.isRecording) { _, rec in if !rec { voice.recordingStopped() } }
    }

    private var field: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(1...4)
            .foregroundStyle(theme.colors.label)
            .focused($focused)
            .submitLabel(.send)
            .onSubmit(send)
            .accessibilityIdentifier(style == .inline ? "followUpField" : "askField")
    }

    private var mic: some View {
        PushToTalkButton(
            isDictating: voice.mode == .dictating, isHolding: holding,
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
        Button(action: send) {
            Label("Send", systemImage: "arrow.up.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .frame(minWidth: theme.size.minTapTarget, minHeight: theme.size.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("send")
    }

    private func send() { submit(text) }

    /// Sends `raw`; false when there is nothing to send.
    @discardableResult
    private func submit(_ raw: String) -> Bool {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        voice.stopDictation()
        focused = false
        onSend(q)
        return true
    }
}

private struct AskFieldPreview: View {
    @State var text: String
    var style: AskField.Style = .floating
    @State private var voice = AskController()
    var body: some View {
        AskField(text: $text, voice: voice, style: style) { _ in }
    }
}

#Preview("Floating") {
    VStack(spacing: 16) {
        AskFieldPreview(text: "")
        AskFieldPreview(text: "Can I keep unused energy with a Battery?")
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(Fixtures.pageBackdrop)
    .themed()
}

#Preview("Inline") {
    AskFieldPreview(text: "", style: .inline)
        .padding()
        .themeBackground(\.sheet)
        .themed()
}

#Preview("AX5") {
    AskFieldPreview(text: "Can I keep unused energy with a Battery?")
        .padding()
        .background(Fixtures.pageBackdrop)
        .themed()
        .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    AskFieldPreview(text: "")
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Fixtures.pageBackdrop)
        .themed()
        .preferredColorScheme(.dark)
}
