import Foundation
import SwiftData

@Model
final class VoiceProfile {
    var id: UUID
    var status: VoiceCloneStatus
    var provider: VoiceCloneProvider
    var voiceId: String?
    var voiceName: String?
    var sampleCount: Int
    var totalDuration: TimeInterval
    var lastTrainedAt: Date?
    var trainingStartedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Provider-specific
    var elevenLabsModelId: String?
    var customEndpoint: String?

    // Quality metrics
    var averageQuality: Double?
    var trainingError: String?

    init(provider: VoiceCloneProvider = .elevenLabs) {
        self.id = UUID()
        self.status = .notStarted
        self.provider = provider
        self.voiceId = nil
        self.voiceName = nil
        self.sampleCount = 0
        self.totalDuration = 0
        self.lastTrainedAt = nil
        self.trainingStartedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.elevenLabsModelId = nil
        self.customEndpoint = nil
        self.averageQuality = nil
        self.trainingError = nil
    }

    // MARK: - Computed Properties

    var isReady: Bool { status == .ready }

    var canStartTraining: Bool {
        totalDuration >= VoiceCloneConstants.minimumDuration && status != .training
    }

    var durationProgress: Double {
        min(totalDuration / VoiceCloneConstants.recommendedDuration, 1.0)
    }

    var durationProgressText: String {
        let current = Int(totalDuration)
        let recommended = Int(VoiceCloneConstants.recommendedDuration)
        return String(localized: "voice.duration_progress \(current) \(recommended)")
    }

    var statusDescription: String {
        switch status {
        case .notStarted:
            return String(localized: "voice.status.not_started")
        case .collecting:
            return String(localized: "voice.status.collecting")
        case .training:
            return String(localized: "voice.status.training")
        case .ready:
            return String(localized: "voice.status.ready")
        case .failed:
            return String(localized: "voice.status.failed")
        }
    }

    // MARK: - Methods

    func addSample(duration: TimeInterval) {
        sampleCount += 1
        totalDuration += duration
        updatedAt = Date()
        if status == .notStarted {
            status = .collecting
        }
    }

    func removeSample(duration: TimeInterval) {
        sampleCount = max(0, sampleCount - 1)
        totalDuration = max(0, totalDuration - duration)
        updatedAt = Date()
    }

    func startTraining() {
        status = .training
        trainingStartedAt = Date()
        trainingError = nil
        updatedAt = Date()
    }

    func completeTraining(voiceId: String) {
        self.voiceId = voiceId
        status = .ready
        lastTrainedAt = Date()
        updatedAt = Date()
    }

    func failTraining(error: String) {
        status = .failed
        trainingError = error
        updatedAt = Date()
    }

    func reset() {
        status = .notStarted
        voiceId = nil
        sampleCount = 0
        totalDuration = 0
        lastTrainedAt = nil
        trainingStartedAt = nil
        trainingError = nil
        updatedAt = Date()
    }
}

// MARK: - Voice Clone Status

enum VoiceCloneStatus: String, Codable {
    case notStarted = "not_started"
    case collecting = "collecting"
    case training = "training"
    case ready = "ready"
    case failed = "failed"

    var icon: String {
        switch self {
        case .notStarted: return "waveform.badge.plus"
        case .collecting: return "waveform"
        case .training: return "gearshape.2"
        case .ready: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .notStarted: return "secondary"
        case .collecting: return "blue"
        case .training: return "orange"
        case .ready: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Voice Clone Provider

enum VoiceCloneProvider: String, Codable, CaseIterable {
    case elevenLabs = "eleven_labs"
    case openAITTS = "openai_tts"  // Fallback, not actual cloning
    case custom = "custom"

    var label: String {
        switch self {
        case .elevenLabs: return "ElevenLabs"
        case .openAITTS: return "OpenAI TTS"
        case .custom: return String(localized: "voice.provider.custom")
        }
    }

    var description: String {
        switch self {
        case .elevenLabs:
            return String(localized: "voice.provider.elevenlabs.desc")
        case .openAITTS:
            return String(localized: "voice.provider.openai.desc")
        case .custom:
            return String(localized: "voice.provider.custom.desc")
        }
    }

    var supportsCloning: Bool {
        switch self {
        case .elevenLabs, .custom: return true
        case .openAITTS: return false
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .elevenLabs, .openAITTS: return true
        case .custom: return true
        }
    }
}

// MARK: - Constants

enum VoiceCloneConstants {
    static let minimumDuration: TimeInterval = 180  // 3 minutes
    static let recommendedDuration: TimeInterval = 600  // 10 minutes
    static let optimalDuration: TimeInterval = 1800  // 30 minutes

    static let minimumSampleDuration: TimeInterval = 10  // 10 seconds per sample
    static let maximumSampleDuration: TimeInterval = 120  // 2 minutes per sample

    static let keychainService = "com.tyndall.memory.voice"
}

// MARK: - ElevenLabs Models

enum ElevenLabsModel: String, CaseIterable {
    case multilingualV2 = "eleven_multilingual_v2"
    case turboV2 = "eleven_turbo_v2"
    case monolingualV1 = "eleven_monolingual_v1"

    var label: String {
        switch self {
        case .multilingualV2: return "Multilingual v2"
        case .turboV2: return "Turbo v2"
        case .monolingualV1: return "Monolingual v1"
        }
    }

    var description: String {
        switch self {
        case .multilingualV2: return String(localized: "elevenlabs.model.multilingual")
        case .turboV2: return String(localized: "elevenlabs.model.turbo")
        case .monolingualV1: return String(localized: "elevenlabs.model.monolingual")
        }
    }
}
