import Foundation
import AVFoundation
import Security

@Observable
final class VoiceCloneService {
    static let shared = VoiceCloneService()

    var isRecording = false
    var isTraining = false
    var isSynthesizing = false
    var trainingProgress: Double = 0.0
    var lastError: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentRecordingDuration: TimeInterval = 0

    private init() {}

    // MARK: - API Key Management

    func saveAPIKey(_ key: String, for provider: VoiceCloneProvider) {
        let service = VoiceCloneConstants.keychainService
        let account = provider.rawValue

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(key.utf8)
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func getAPIKey(for provider: VoiceCloneProvider) -> String? {
        let service = VoiceCloneConstants.keychainService
        let account = provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey(for provider: VoiceCloneProvider) {
        let service = VoiceCloneConstants.keychainService
        let account = provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasAPIKey(for provider: VoiceCloneProvider) -> Bool {
        getAPIKey(for: provider) != nil
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let samplesDir = documentsPath.appendingPathComponent("VoiceSamples")

        if !FileManager.default.fileExists(atPath: samplesDir.path) {
            try FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)
        }

        let fileName = "sample_\(UUID().uuidString).m4a"
        let fileURL = samplesDir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        currentRecordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentRecordingDuration += 0.1
            self?.audioRecorder?.updateMeters()
        }

        return fileURL
    }

    func stopRecording() -> (URL, TimeInterval)? {
        guard let recorder = audioRecorder else { return nil }

        let url = recorder.url
        let duration = recorder.currentTime

        recorder.stop()
        audioRecorder = nil
        isRecording = false

        recordingTimer?.invalidate()
        recordingTimer = nil

        return (url, duration)
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }

        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false

        recordingTimer?.invalidate()
        recordingTimer = nil

        // Delete the file
        try? FileManager.default.removeItem(at: url)
    }

    var currentMeterLevel: Float {
        audioRecorder?.averagePower(forChannel: 0) ?? -160
    }

    var recordingDuration: TimeInterval {
        currentRecordingDuration
    }

    // MARK: - Quality Evaluation

    func evaluateQuality(sampleURL: URL) async -> (volume: Float, noise: Float, clarity: Float) {
        // Simplified quality evaluation
        // In production, use audio analysis frameworks

        guard let audioFile = try? AVAudioFile(forReading: sampleURL) else {
            return (0, 1, 0)
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return (0, 1, 0)
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            return (0, 1, 0)
        }

        guard let floatData = buffer.floatChannelData?[0] else {
            return (0, 1, 0)
        }

        var sum: Float = 0
        var maxSample: Float = 0
        var silentFrames = 0

        for i in 0..<Int(frameCount) {
            let sample = abs(floatData[i])
            sum += sample
            maxSample = max(maxSample, sample)
            if sample < 0.01 {
                silentFrames += 1
            }
        }

        let averageVolume = sum / Float(frameCount)
        let silenceRatio = Float(silentFrames) / Float(frameCount)

        // Normalize to 0-1 range
        let volumeScore = min(averageVolume * 10, 1.0)
        let noiseScore: Float = silenceRatio > 0.5 ? 0.8 : 0.2  // High silence = low noise
        let clarityScore: Float = maxSample > 0.3 ? 0.8 : 0.4  // Good dynamic range = clarity

        return (volumeScore, 1 - noiseScore, clarityScore)
    }

    // MARK: - ElevenLabs Integration

    func trainWithElevenLabs(
        profile: VoiceProfile,
        samples: [VoiceSample],
        name: String
    ) async throws {
        guard let apiKey = getAPIKey(for: .elevenLabs) else {
            throw VoiceCloneError.missingAPIKey
        }

        isTraining = true
        trainingProgress = 0.0
        lastError = nil

        defer { isTraining = false }

        // Prepare files for upload
        var audioFiles: [(Data, String)] = []
        for sample in samples where sample.isUsedForTraining {
            guard let url = sample.audioURL,
                  let data = try? Data(contentsOf: url) else { continue }
            audioFiles.append((data, sample.audioFilePath))
        }

        guard !audioFiles.isEmpty else {
            throw VoiceCloneError.noSamples
        }

        trainingProgress = 0.1

        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add name
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"name\"\r\n\r\n".utf8))
        body.append(Data("\(name)\r\n".utf8))

        // Add description
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"description\"\r\n\r\n".utf8))
        body.append(Data("Voice clone created by Memory app\r\n".utf8))

        // Add files
        for (index, (data, filename)) in audioFiles.enumerated() {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".utf8))
            body.append(Data("Content-Type: audio/mpeg\r\n\r\n".utf8))
            body.append(data)
            body.append(Data("\r\n".utf8))

            trainingProgress = 0.1 + 0.4 * Double(index + 1) / Double(audioFiles.count)
        }

        body.append(Data("--\(boundary)--\r\n".utf8))

        // Make request
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices/add") else {
            throw VoiceCloneError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        trainingProgress = 0.6

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloneError.networkError
        }

        trainingProgress = 0.8

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let voiceId = json["voice_id"] as? String {
                profile.completeTraining(voiceId: voiceId)
                profile.voiceName = name
                trainingProgress = 1.0
            } else {
                throw VoiceCloneError.invalidResponse
            }
        } else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                throw VoiceCloneError.apiError(detail)
            }
            throw VoiceCloneError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Voice Synthesis

    func synthesize(
        text: String,
        profile: VoiceProfile
    ) async throws -> URL {
        guard profile.isReady, let voiceId = profile.voiceId else {
            throw VoiceCloneError.voiceNotReady
        }

        isSynthesizing = true
        defer { isSynthesizing = false }

        switch profile.provider {
        case .elevenLabs:
            return try await synthesizeWithElevenLabs(text: text, voiceId: voiceId)
        case .openAITTS:
            return try await synthesizeWithOpenAI(text: text)
        case .custom:
            guard let endpoint = profile.customEndpoint else {
                throw VoiceCloneError.missingEndpoint
            }
            return try await synthesizeWithCustom(text: text, voiceId: voiceId, endpoint: endpoint)
        }
    }

    private func synthesizeWithElevenLabs(text: String, voiceId: String) async throws -> URL {
        guard let apiKey = getAPIKey(for: .elevenLabs) else {
            throw VoiceCloneError.missingAPIKey
        }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)") else {
            throw VoiceCloneError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceCloneError.synthesisError
        }

        // Save to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).mp3")
        try data.write(to: tempURL)

        return tempURL
    }

    private func synthesizeWithOpenAI(text: String) async throws -> URL {
        guard let apiKey = getAPIKey(for: .openAITTS) else {
            throw VoiceCloneError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw VoiceCloneError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": "onyx"  // Default voice, not cloned
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceCloneError.synthesisError
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).mp3")
        try data.write(to: tempURL)

        return tempURL
    }

    private func synthesizeWithCustom(text: String, voiceId: String, endpoint: String) async throws -> URL {
        guard let apiKey = getAPIKey(for: .custom) else {
            throw VoiceCloneError.missingAPIKey
        }

        guard let url = URL(string: endpoint) else {
            throw VoiceCloneError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "voice_id": voiceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceCloneError.synthesisError
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).mp3")
        try data.write(to: tempURL)

        return tempURL
    }

    // MARK: - Voice Management

    func deleteVoice(profile: VoiceProfile) async throws {
        guard let voiceId = profile.voiceId else { return }

        if profile.provider == .elevenLabs {
            guard let apiKey = getAPIKey(for: .elevenLabs) else {
                throw VoiceCloneError.missingAPIKey
            }

            guard let url = URL(string: "https://api.elevenlabs.io/v1/voices/\(voiceId)") else {
                throw VoiceCloneError.invalidEndpoint
            }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw VoiceCloneError.deleteError
            }
        }

        profile.reset()
    }

    func previewVoice(profile: VoiceProfile) async throws -> URL {
        let sampleText = String(localized: "voice.preview.text")
        return try await synthesize(text: sampleText, profile: profile)
    }
}

// MARK: - Errors

enum VoiceCloneError: LocalizedError {
    case missingAPIKey
    case missingEndpoint
    case invalidEndpoint
    case noSamples
    case networkError
    case httpError(Int)
    case apiError(String)
    case invalidResponse
    case voiceNotReady
    case synthesisError
    case deleteError
    case recordingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "voice.error.missing_api_key")
        case .missingEndpoint:
            return String(localized: "voice.error.missing_endpoint")
        case .invalidEndpoint:
            return String(localized: "voice.error.invalid_endpoint")
        case .noSamples:
            return String(localized: "voice.error.no_samples")
        case .networkError:
            return String(localized: "voice.error.network")
        case .httpError(let code):
            return String(localized: "voice.error.http \(code)")
        case .apiError(let message):
            return message
        case .invalidResponse:
            return String(localized: "voice.error.invalid_response")
        case .voiceNotReady:
            return String(localized: "voice.error.voice_not_ready")
        case .synthesisError:
            return String(localized: "voice.error.synthesis")
        case .deleteError:
            return String(localized: "voice.error.delete")
        case .recordingError:
            return String(localized: "voice.error.recording")
        }
    }
}
