import Foundation
import AVFoundation
import UIKit
import SwiftUI

/// Manages video recording using AVCaptureSession for video memories.
@Observable
final class VideoRecordingService: NSObject, AVCaptureFileOutputRecordingDelegate {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var currentRecordingURL: URL?
    var cameraPosition: AVCaptureDevice.Position = .back
    var isSessionReady = false

    private(set) var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var timer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        var videoGranted = videoStatus == .authorized
        var audioGranted = audioStatus == .authorized

        if videoStatus == .notDetermined {
            videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        }
        if audioStatus == .notDetermined {
            audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        return videoGranted && audioGranted
    }

    // MARK: - Session Setup

    func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else { return }
        session.addInput(videoInput)

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie output
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        movieOutput = output
        isSessionReady = true

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    /// Switch between front and back cameras.
    func switchCamera() {
        guard let session = captureSession else { return }

        session.beginConfiguration()

        // Remove existing video input
        if let currentInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.hasMediaType(.video) }) {
            session.removeInput(currentInput)
        }

        // Toggle position
        cameraPosition = (cameraPosition == .back) ? .front : .back

        // Add new video input
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        session.commitConfiguration()
    }

    // MARK: - Recording

    func startRecording() {
        guard let output = movieOutput, !isRecording else { return }

        let fileName = "memory_\(UUID().uuidString).mov"
        let url = AudioRecordingService.recordingsDirectory.appendingPathComponent(fileName)

        output.startRecording(to: url, recordingDelegate: self)
        currentRecordingURL = url
        isRecording = true
        recordingDuration = 0
        recordingStartTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let output = movieOutput, isRecording else { return nil }

        let duration = recordingDuration
        output.stopRecording()
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordingStartTime = nil

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

    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
        movieOutput = nil
        isSessionReady = false
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        // Recording finished
    }

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail from the first frame of a video file.
    static func generateThumbnail(for url: URL) -> Data? {
        var videoURL = url

        // In full encryption mode, decrypt to temp first
        if EncryptionLevel.current == .full {
            if let key = try? EncryptionHelper.masterKey(),
               let tempURL = try? EncryptionHelper.decryptFileToTemp(at: url, using: key) {
                videoURL = tempURL
                defer { try? EncryptionHelper.secureDelete(at: tempURL) }
                return generateThumbnailFromURL(videoURL)
            }
        }

        return generateThumbnailFromURL(videoURL)
    }

    private static func generateThumbnailFromURL(_ url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.7)
        } catch {
            return nil
        }
    }

    /// Get the duration of a video file.
    static func videoDuration(for url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        return CMTimeGetSeconds(duration)
    }

    /// The preview layer for the capture session.
    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - Camera Preview View (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            context.coordinator.previewLayer = previewLayer
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
