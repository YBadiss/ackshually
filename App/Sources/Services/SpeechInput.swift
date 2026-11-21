import Foundation
import AVFoundation
import Speech
import Observation

/// Live transcription for push-to-talk (S3). On-device when available.
@MainActor
@Observable
final class SpeechInput {
    private(set) var transcript = ""
    private(set) var isRecording = false
    /// 0…1, for the little waveform.
    private(set) var level: Float = 0
    var error: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func start() async {
        guard !isRecording else { return }
        error = nil
        transcript = ""
        guard await Self.authorize() else {
            error = "Allow Microphone and Speech Recognition in Settings to ask by voice."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognition isn't available right now."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.contextualStrings = ["energy", "victory points", "end of turn", "clearing", "warriors"]
            request = req

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(request: req) { [weak self] lvl in
                Task { @MainActor in self?.level = lvl }
            })
            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: req) { [weak self] result, err in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if err != nil || final { self.teardown() }
                }
            }
        } catch {
            self.error = "Couldn't start the microphone: \(error.localizedDescription)"
            teardown()
        }
    }

    /// Stops listening and returns the transcript so far.
    @discardableResult
    func stop() -> String {
        request?.endAudio()
        teardown()
        return transcript
    }

    func cancel() {
        task?.cancel()
        teardown()
        transcript = ""
    }

    private func teardown() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap runs on the audio thread.
    nonisolated private static func tapBlock(request: SFSpeechAudioBufferRecognitionRequest,
                                             level: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            guard let ch = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += ch[i] * ch[i] }
            let rms = (sum / Float(buffer.frameLength)).squareRoot()
            level(min(1, rms * 12))
        }
    }

    nonisolated private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
