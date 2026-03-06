import Foundation
import Speech

/// Transcribes audio recordings to text using Apple's Speech framework.
@Observable
final class SpeechTranscriptionService {
    var isTranscribing = false
    var transcription: String = ""
    var error: String?

    private var recognizer: SFSpeechRecognizer?

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    /// Request speech recognition permission.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe an audio file at the given URL.
    @discardableResult
    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        isTranscribing = true
        error = nil
        transcription = ""

        defer { isTranscribing = false }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }

        let text = result.bestTranscription.formattedString
        transcription = text
        return text
    }

    /// Live transcription from the microphone using Audio Engine.
    func startLiveTranscription(onUpdate: @escaping (String) -> Void) throws -> LiveTranscriptionSession {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isTranscribing = true

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcription = text
                    onUpdate(text)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                }
            }
        }

        return LiveTranscriptionSession(audioEngine: audioEngine, request: request, task: task)
    }

    enum TranscriptionError: LocalizedError {
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognition is not available on this device."
            }
        }
    }
}

/// Holds references to a live transcription session so it can be stopped.
final class LiveTranscriptionSession {
    private let audioEngine: AVAudioEngine
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let task: SFSpeechRecognitionTask

    init(audioEngine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest, task: SFSpeechRecognitionTask) {
        self.audioEngine = audioEngine
        self.request = request
        self.task = task
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task.cancel()
    }
}
