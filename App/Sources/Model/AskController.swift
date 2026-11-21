import Foundation
import Observation

/// Push-to-talk / dictation state machine (S3) over `SpeechInput`. Injected into `AskBar`.
/// - press + hold (`layout.holdToTalkDelay`) → live transcript; release sends; slide left cancels
/// - tap → dictation into the field; tap again to stop and edit before sending
@MainActor
@Observable
final class AskController {
    enum Mode: Equatable { case idle, holding, dictating }

    private(set) var mode: Mode = .idle
    private(set) var cancelArmed = false
    let speech: SpeechInput

    private var pressed = false
    private var holdTask: Task<Void, Never>?
    private var dictationPrefix = ""

    init(speech: SpeechInput = SpeechInput()) {
        self.speech = speech
    }

    var transcript: String { speech.transcript }
    var level: Float { speech.level }
    var error: String? { speech.error }

    func pressBegan(holdDelay: Duration) {
        guard !pressed else { return }
        pressed = true
        guard mode == .idle else { return }
        holdTask = Task {
            try? await Task.sleep(for: holdDelay)
            guard !Task.isCancelled, pressed else { return }
            mode = .holding
            cancelArmed = false
            await speech.start()
            if !speech.isRecording, mode == .holding { mode = .idle }
        }
    }

    func dragChanged(dx: CGFloat, cancelThreshold: CGFloat) {
        if mode == .holding { cancelArmed = dx < -cancelThreshold }
    }

    /// Returns a question to send (hold released), or nil.
    func pressEnded(currentText: String) -> String? {
        holdTask?.cancel()
        pressed = false
        switch mode {
        case .holding:
            mode = .idle
            defer { cancelArmed = false }
            if cancelArmed { speech.cancel(); return nil }
            let said = speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
            return said.isEmpty ? nil : said
        case .dictating, .idle:
            toggleDictation(currentText: currentText)
            return nil
        }
    }

    func toggleDictation(currentText: String) {
        if mode == .dictating {
            speech.stop()
            mode = .idle
            return
        }
        dictationPrefix = currentText.isEmpty ? "" : currentText + " "
        mode = .dictating
        Task {
            await speech.start()
            if !speech.isRecording { mode = .idle }
        }
    }

    /// Field text while dictating.
    func dictatedText() -> String? {
        mode == .dictating ? dictationPrefix + speech.transcript : nil
    }

    func recordingStopped() {
        if mode == .dictating { mode = .idle }
    }

    func stopDictation() {
        if mode == .dictating { speech.stop(); mode = .idle }
    }
}
