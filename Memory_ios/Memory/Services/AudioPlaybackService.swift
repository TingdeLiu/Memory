import Foundation
import AVFoundation

/// Manages audio playback for recorded voice memories.
@Observable
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var decryptedTempURL: URL?

    /// Play audio from a file URL. In full encryption mode, decrypts to a temp file first.
    func play(url: URL) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        var playbackURL = url

        // In full encryption mode, decrypt to temp file for playback
        if EncryptionLevel.current == .full {
            if let key = try? EncryptionHelper.masterKey() {
                if let tempURL = try? EncryptionHelper.decryptFileToTemp(at: url, using: key) {
                    playbackURL = tempURL
                    decryptedTempURL = tempURL
                }
            }
        }

        audioPlayer = try AVAudioPlayer(contentsOf: playbackURL)
        audioPlayer?.delegate = self
        duration = audioPlayer?.duration ?? 0
        audioPlayer?.play()
        isPlaying = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.progress = self.duration > 0 ? player.currentTime / self.duration : 0
        }
    }

    /// Pause playback.
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    /// Resume playback.
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.progress = self.duration > 0 ? player.currentTime / self.duration : 0
        }
    }

    /// Stop playback and clean up any decrypted temp files.
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = 0
        progress = 0
        cleanupTempFile()
    }

    /// Seek to a specific position (0...1).
    func seek(to fraction: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
        progress = fraction
    }

    /// Toggle play/pause.
    func togglePlayback(url: URL) throws {
        if isPlaying {
            pause()
        } else if audioPlayer != nil {
            resume()
        } else {
            try play(url: url)
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.currentTime = 0
            self?.progress = 0
            self?.timer?.invalidate()
            self?.timer = nil
            self?.cleanupTempFile()
        }
    }

    // MARK: - Private

    private func cleanupTempFile() {
        if let tempURL = decryptedTempURL {
            try? EncryptionHelper.secureDelete(at: tempURL)
            decryptedTempURL = nil
        }
    }
}
