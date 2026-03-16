import Foundation
import SwiftData

@Model
final class VoiceSample {
    var id: UUID
    var audioFilePath: String
    var duration: TimeInterval
    var transcription: String?
    var promptText: String?  // The text user was asked to read
    var quality: VoiceSampleQuality
    var isUsedForTraining: Bool
    var sourceType: VoiceSampleSource
    var sourceId: UUID?  // Link to MemoryEntry or Message if extracted
    var createdAt: Date

    // Quality metrics
    var averageVolume: Float?
    var noiseLevel: Float?
    var clarityScore: Float?

    init(
        audioFilePath: String,
        duration: TimeInterval,
        transcription: String? = nil,
        promptText: String? = nil,
        sourceType: VoiceSampleSource = .recorded,
        sourceId: UUID? = nil
    ) {
        self.id = UUID()
        self.audioFilePath = audioFilePath
        self.duration = duration
        self.transcription = transcription
        self.promptText = promptText
        self.quality = .pending
        self.isUsedForTraining = false
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.createdAt = Date()
        self.averageVolume = nil
        self.noiseLevel = nil
        self.clarityScore = nil
    }

    // MARK: - Computed Properties

    var audioURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("VoiceSamples").appendingPathComponent(audioFilePath)
    }

    var durationText: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "0:%02d", seconds)
    }

    var qualityIcon: String {
        quality.icon
    }

    var qualityColor: String {
        quality.color
    }

    var isGoodEnough: Bool {
        quality == .excellent || quality == .good
    }

    // MARK: - Methods

    func updateQuality(volume: Float, noise: Float, clarity: Float) {
        self.averageVolume = volume
        self.noiseLevel = noise
        self.clarityScore = clarity

        // Calculate overall quality
        var score: Float = 0

        // Volume (ideal: -20 to -10 dB normalized to 0.3-0.7)
        if volume >= 0.3 && volume <= 0.7 {
            score += 0.33
        } else if volume >= 0.2 && volume <= 0.8 {
            score += 0.2
        }

        // Noise (lower is better)
        if noise < 0.1 {
            score += 0.33
        } else if noise < 0.2 {
            score += 0.2
        }

        // Clarity (higher is better)
        if clarity > 0.8 {
            score += 0.34
        } else if clarity > 0.6 {
            score += 0.2
        }

        if score >= 0.9 {
            quality = .excellent
        } else if score >= 0.7 {
            quality = .good
        } else if score >= 0.5 {
            quality = .fair
        } else {
            quality = .poor
        }
    }

    func markForTraining() {
        isUsedForTraining = true
    }

    func excludeFromTraining() {
        isUsedForTraining = false
    }
}

// MARK: - Voice Sample Quality

enum VoiceSampleQuality: String, Codable {
    case pending = "pending"
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var label: String {
        switch self {
        case .pending: return String(localized: "voice.quality.pending")
        case .excellent: return String(localized: "voice.quality.excellent")
        case .good: return String(localized: "voice.quality.good")
        case .fair: return String(localized: "voice.quality.fair")
        case .poor: return String(localized: "voice.quality.poor")
        }
    }

    var icon: String {
        switch self {
        case .pending: return "hourglass"
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "minus.circle"
        case .poor: return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "secondary"
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - Voice Sample Source

enum VoiceSampleSource: String, Codable {
    case recorded = "recorded"      // Dedicated voice training recording
    case memory = "memory"          // Extracted from voice memory
    case message = "message"        // Extracted from voice message

    var label: String {
        switch self {
        case .recorded: return String(localized: "voice.source.recorded")
        case .memory: return String(localized: "voice.source.memory")
        case .message: return String(localized: "voice.source.message")
        }
    }

    var icon: String {
        switch self {
        case .recorded: return "mic.fill"
        case .memory: return "brain.head.profile"
        case .message: return "envelope.fill"
        }
    }
}

// MARK: - Training Prompts

struct VoiceTrainingPrompts {
    static let prompts: [String] = [
        String(localized: "voice.prompt.1"),
        String(localized: "voice.prompt.2"),
        String(localized: "voice.prompt.3"),
        String(localized: "voice.prompt.4"),
        String(localized: "voice.prompt.5"),
        String(localized: "voice.prompt.6"),
        String(localized: "voice.prompt.7"),
        String(localized: "voice.prompt.8"),
        String(localized: "voice.prompt.9"),
        String(localized: "voice.prompt.10"),
        String(localized: "voice.prompt.11"),
        String(localized: "voice.prompt.12"),
        String(localized: "voice.prompt.13"),
        String(localized: "voice.prompt.14"),
        String(localized: "voice.prompt.15"),
    ]

    static let emotionalPrompts: [String] = [
        String(localized: "voice.prompt.happy"),
        String(localized: "voice.prompt.sad"),
        String(localized: "voice.prompt.excited"),
        String(localized: "voice.prompt.calm"),
        String(localized: "voice.prompt.serious"),
    ]

    static let numbersAndDates: [String] = [
        String(localized: "voice.prompt.numbers"),
        String(localized: "voice.prompt.days"),
        String(localized: "voice.prompt.months"),
    ]

    static var randomPrompt: String {
        let allPrompts = prompts + emotionalPrompts + numbersAndDates
        return allPrompts.randomElement() ?? prompts[0]
    }

    static func prompt(at index: Int) -> String {
        let allPrompts = prompts + emotionalPrompts + numbersAndDates
        return allPrompts[index % allPrompts.count]
    }
}
