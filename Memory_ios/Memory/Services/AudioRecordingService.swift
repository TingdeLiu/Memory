import Foundation
import AVFoundation

/// Manages audio recording for voice memories and messages.
@Observable
final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var currentRecordingURL: URL?
    var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    deinit {
        timer?.invalidate()
        audioRecorder?.stop()
    }

    /// Request microphone permission.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Start recording audio to a new file.
    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let fileName = "memory_\(UUID().uuidString).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        currentRecordingURL = url
        isRecording = true
        recordingDuration = 0
        audioLevel = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            self.recordingDuration = recorder.currentTime
            // Normalize average power (-160...0 dB) to 0...1
            let power = recorder.averagePower(forChannel: 0)
            self.audioLevel = max(0, min(1, (power + 50) / 50))
        }
    }

    /// Stop the current recording and return the file URL and duration.
    /// In full encryption mode, the file is automatically encrypted after recording.
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        audioLevel = 0

        let url = currentRecordingURL
        currentRecordingURL = nil

        if let url {
            // Auto-encrypt in full encryption mode
            if EncryptionLevel.current == .full {
                if let key = try? EncryptionHelper.masterKey() {
                    try? EncryptionHelper.encryptFile(at: url, using: key)
                }
            }
            return (url, duration)
        }
        return nil
    }

    /// Delete a recording file.
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Get the URL for a recording by its file name.
    static func recordingURL(for fileName: String) -> URL {
        recordingsDirectory.appendingPathComponent(fileName)
    }

    /// Directory where all recordings are stored.
    static var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
