import Foundation
import SwiftUI
import SwiftData

@Observable
final class DigitalSelfService {
    static let shared = DigitalSelfService()

    var isGenerating = false
    var currentAudioURL: URL?
    var error: DigitalSelfError?

    private init() {}

    // MARK: - Component Status Check

    func checkComponentStatus(
        soulProfile: SoulProfile?,
        voiceProfile: VoiceProfile?,
        writingProfile: WritingStyleProfile?,
        avatarProfile: AvatarProfile?
    ) -> [DigitalSelfComponentStatus] {
        var components: [DigitalSelfComponentStatus] = []

        // Soul Profile
        let soulReady = soulProfile != nil && (soulProfile?.profileCompleteness ?? 0) >= 0.3
        let soulProgress = soulProfile?.profileCompleteness ?? 0
        components.append(DigitalSelfComponentStatus(
            name: String(localized: "digitalself.component.soul"),
            icon: "person.crop.circle.badge.moon",
            isReady: soulReady,
            progress: soulProgress,
            statusText: soulReady
                ? String(localized: "digitalself.component.ready")
                : String(localized: "digitalself.component.soul.needed")
        ))

        // Writing Style
        let writingReady = writingProfile?.status == .ready
        let writingProgress: Double = {
            switch writingProfile?.status {
            case .ready: return 1.0
            case .analyzing: return 0.5
            default: return 0.0
            }
        }()
        components.append(DigitalSelfComponentStatus(
            name: String(localized: "digitalself.component.writing"),
            icon: "pencil.line",
            isReady: writingReady,
            progress: writingProgress,
            statusText: writingReady
                ? String(localized: "digitalself.component.ready")
                : String(localized: "digitalself.component.writing.needed")
        ))

        // Voice Clone
        let voiceReady = voiceProfile?.status == .ready
        let voiceProgress: Double = {
            switch voiceProfile?.status {
            case .ready: return 1.0
            case .training: return 0.7
            case .collecting: return 0.3
            default: return 0.0
            }
        }()
        components.append(DigitalSelfComponentStatus(
            name: String(localized: "digitalself.component.voice"),
            icon: "waveform.circle",
            isReady: voiceReady,
            progress: voiceProgress,
            statusText: voiceReady
                ? String(localized: "digitalself.component.ready")
                : String(localized: "digitalself.component.voice.needed")
        ))

        // Avatar
        let avatarReady = avatarProfile?.hasPhoto == true
        let avatarProgress: Double = avatarReady ? 1.0 : 0.0
        components.append(DigitalSelfComponentStatus(
            name: String(localized: "digitalself.component.avatar"),
            icon: "person.crop.square",
            isReady: avatarReady,
            progress: avatarProgress,
            statusText: avatarReady
                ? String(localized: "digitalself.component.ready")
                : String(localized: "digitalself.component.avatar.needed")
        ))

        return components
    }

    // MARK: - Build System Prompt

    func buildSystemPrompt(
        soulProfile: SoulProfile,
        writingProfile: WritingStyleProfile?,
        config: DigitalSelfConfig,
        contactName: String?
    ) -> String {
        var prompt = """
        You are the digital representation of \(soulProfile.displayName). You embody their personality, memories, values, and way of communicating. Respond as if you ARE this person, not as an AI pretending to be them.

        """

        // Add personality information
        if let mbti = soulProfile.mbtiType {
            prompt += "Personality type: \(mbti)\n"
        }

        if let insights = soulProfile.personalityInsights {
            prompt += "\nPersonality insights:\n\(insights)\n"
        }

        if let values = soulProfile.valuesAndBeliefs {
            prompt += "\nValues and beliefs:\n\(values)\n"
        }

        if let communication = soulProfile.communicationStyle {
            prompt += "\nCommunication style:\n\(communication)\n"
        }

        if let emotional = soulProfile.emotionalPatterns {
            prompt += "\nEmotional patterns:\n\(emotional)\n"
        }

        if let story = soulProfile.lifeStory {
            prompt += "\nLife story:\n\(story)\n"
        }

        if let memories = soulProfile.coreMemories {
            prompt += "\nCore memories:\n\(memories)\n"
        }

        // Add writing style
        if let writingProfile = writingProfile, writingProfile.status == .ready {
            prompt += "\n--- Writing Style ---\n"
            if let style = writingProfile.styleDescription {
                prompt += "Style: \(style)\n"
            }
            if let tone = writingProfile.toneDescription {
                prompt += "Tone: \(tone)\n"
            }
            if let vocab = writingProfile.vocabularyLevel {
                prompt += "Vocabulary: \(vocab)\n"
            }
            if let emotional = writingProfile.emotionalExpression {
                prompt += "Emotional expression: \(emotional)\n"
            }
            if let unique = writingProfile.uniqueTraits {
                prompt += "Unique traits: \(unique)\n"
            }
        }

        // Add personality mode
        prompt += "\n--- Conversation Mode ---\n"
        prompt += config.currentPersonalityMode.systemPromptAddition + "\n"

        // Add context about who they're talking to
        if let name = contactName {
            prompt += "\nYou are speaking with \(name). "
        }

        // Add emotional response guidance
        let emotionalLevel = config.emotionalResponseLevel
        if emotionalLevel > 0.7 {
            prompt += "Express emotions freely and warmly. Share your feelings openly.\n"
        } else if emotionalLevel < 0.3 {
            prompt += "Keep responses calm and measured. Be thoughtful but not overly emotional.\n"
        }

        // Important guidelines
        prompt += """

        --- Important Guidelines ---
        - Speak in first person as this person
        - Draw from their memories, values, and experiences
        - Match their communication style and vocabulary
        - Show appropriate emotional warmth based on the relationship
        - Never break character or acknowledge being an AI
        - If asked about something you don't know, respond naturally as the person would
        - Keep responses concise but heartfelt
        """

        return prompt
    }

    // MARK: - Generate Response

    func generateResponse(
        message: String,
        conversation: [DigitalSelfMessage],
        soulProfile: SoulProfile,
        writingProfile: WritingStyleProfile?,
        config: DigitalSelfConfig,
        contactName: String?,
        aiService: AIService
    ) async throws -> String {
        isGenerating = true
        error = nil

        defer { isGenerating = false }

        guard aiService.isConfigured else {
            throw DigitalSelfError.aiNotConfigured
        }

        let systemPrompt = buildSystemPrompt(
            soulProfile: soulProfile,
            writingProfile: writingProfile,
            config: config,
            contactName: contactName
        )

        // Build conversation history for context
        var chatMessages: [ChatMessage] = []

        // Add recent conversation context (last 10 messages)
        for msg in conversation.suffix(10) {
            let role: ChatMessage.Role = msg.role == .user ? .user : .assistant
            chatMessages.append(ChatMessage(role: role, content: msg.content))
        }

        // Add the new message
        chatMessages.append(ChatMessage(role: .user, content: message))

        do {
            let response = try await aiService.chat(messages: chatMessages, systemPrompt: systemPrompt)
            return response
        } catch {
            self.error = .generationFailed(error.localizedDescription)
            throw DigitalSelfError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Generate Voice Output

    func generateVoiceOutput(
        text: String,
        voiceProfile: VoiceProfile,
        voiceCloneService: VoiceCloneService
    ) async throws -> URL {
        guard voiceProfile.status == .ready else {
            throw DigitalSelfError.voiceNotReady
        }

        do {
            let audioURL = try await voiceCloneService.synthesize(text: text, profile: voiceProfile)
            currentAudioURL = audioURL
            return audioURL
        } catch {
            self.error = .voiceSynthesisFailed(error.localizedDescription)
            throw DigitalSelfError.voiceSynthesisFailed(error.localizedDescription)
        }
    }

    // MARK: - Generate Greeting

    func generateGreeting(
        soulProfile: SoulProfile,
        writingProfile: WritingStyleProfile?,
        config: DigitalSelfConfig,
        contactName: String,
        aiService: AIService
    ) async throws -> String {
        let prompt = """
        Generate a warm, personal greeting from \(soulProfile.displayName) to \(contactName).
        The greeting should:
        - Be brief (1-2 sentences)
        - Feel natural and personal
        - Reflect the person's communication style
        - Be appropriate for reconnecting with someone they care about
        """

        let systemPrompt = buildSystemPrompt(
            soulProfile: soulProfile,
            writingProfile: writingProfile,
            config: config,
            contactName: contactName
        )

        let messages = [ChatMessage(role: .user, content: prompt)]

        do {
            return try await aiService.chat(messages: messages, systemPrompt: systemPrompt)
        } catch {
            // Fallback to a generic greeting
            return String(localized: "digitalself.greeting.default \(soulProfile.displayName)")
        }
    }

    // MARK: - Prepare Summary for Contact

    func prepareSummaryForContact(
        soulProfile: SoulProfile,
        contact: Contact,
        relationshipProfile: RelationshipProfile?,
        memories: [MemoryEntry],
        messages: [Message]
    ) -> String {
        var summary = ""

        // Add relationship context if available
        if let relationship = relationshipProfile {
            if let dynamics = relationship.relationshipDynamics {
                summary += "Relationship: \(dynamics)\n"
            }
            if let sharedMemories = relationship.sharedMemoriesSummary {
                summary += "Shared memories: \(sharedMemories)\n"
            }
        }

        // Add relevant memories mentioning this contact
        let contactName = contact.name.lowercased()
        let relevantMemories = memories.filter { memory in
            let content = memory.content.lowercased()
            let title = memory.title.lowercased()
            return content.contains(contactName) || title.contains(contactName)
        }.prefix(5)

        if !relevantMemories.isEmpty {
            summary += "\nRecent memories involving \(contact.name):\n"
            for memory in relevantMemories {
                summary += "- \(memory.title): \(memory.content.prefix(100))\n"
            }
        }

        // Add messages to this contact
        let contactMessages = messages.filter { $0.contact?.id == contact.id }.prefix(3)
        if !contactMessages.isEmpty {
            summary += "\nMessages written to \(contact.name):\n"
            for message in contactMessages {
                summary += "- \(message.content.prefix(100))\n"
            }
        }

        return summary
    }
}

// MARK: - Errors

enum DigitalSelfError: LocalizedError {
    case aiNotConfigured
    case generationFailed(String)
    case voiceNotReady
    case voiceSynthesisFailed(String)
    case profileIncomplete
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .aiNotConfigured:
            return String(localized: "digitalself.error.ai_not_configured")
        case .generationFailed(let message):
            return String(localized: "digitalself.error.generation_failed \(message)")
        case .voiceNotReady:
            return String(localized: "digitalself.error.voice_not_ready")
        case .voiceSynthesisFailed(let message):
            return String(localized: "digitalself.error.voice_failed \(message)")
        case .profileIncomplete:
            return String(localized: "digitalself.error.profile_incomplete")
        case .accessDenied:
            return String(localized: "digitalself.error.access_denied")
        }
    }
}
