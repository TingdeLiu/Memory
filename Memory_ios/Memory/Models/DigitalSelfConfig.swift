import Foundation
import SwiftData

@Model
final class DigitalSelfConfig {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Status

    var isEnabled: Bool
    var status: String  // DigitalSelfStatus.rawValue

    // MARK: - Component Readiness

    var hasSoulProfile: Bool
    var hasVoiceClone: Bool
    var hasWritingStyle: Bool
    var hasAvatar: Bool

    // MARK: - Access Control

    var allowedContactIds: [String]  // UUID strings of contacts who can interact
    var accessMode: String  // DigitalSelfAccessMode.rawValue

    // MARK: - Personality Settings

    var personalityMode: String  // DigitalSelfPersonalityMode.rawValue
    var voiceOutputEnabled: Bool
    var autoGreetEnabled: Bool
    var emotionalResponseLevel: Double  // 0.0 = neutral, 1.0 = highly emotional

    // MARK: - Conversation History (JSON)

    var conversationHistoryData: Data?  // [[String: Any]] - recent conversations

    // MARK: - Statistics

    var totalConversations: Int
    var totalMessages: Int
    var lastInteractionDate: Date?

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isEnabled = false
        self.status = DigitalSelfStatus.notReady.rawValue
        self.hasSoulProfile = false
        self.hasVoiceClone = false
        self.hasWritingStyle = false
        self.hasAvatar = false
        self.allowedContactIds = []
        self.accessMode = DigitalSelfAccessMode.selectedContacts.rawValue
        self.personalityMode = DigitalSelfPersonalityMode.authentic.rawValue
        self.voiceOutputEnabled = true
        self.autoGreetEnabled = true
        self.emotionalResponseLevel = 0.7
        self.conversationHistoryData = nil
        self.totalConversations = 0
        self.totalMessages = 0
        self.lastInteractionDate = nil
    }

    // MARK: - Computed Properties

    var currentStatus: DigitalSelfStatus {
        get { DigitalSelfStatus(rawValue: status) ?? .notReady }
        set { status = newValue.rawValue }
    }

    var currentAccessMode: DigitalSelfAccessMode {
        get { DigitalSelfAccessMode(rawValue: accessMode) ?? .selectedContacts }
        set { accessMode = newValue.rawValue }
    }

    var currentPersonalityMode: DigitalSelfPersonalityMode {
        get { DigitalSelfPersonalityMode(rawValue: personalityMode) ?? .authentic }
        set { personalityMode = newValue.rawValue }
    }

    var readinessScore: Double {
        var score = 0.0
        if hasSoulProfile { score += 0.4 }  // Soul profile is most important
        if hasWritingStyle { score += 0.25 }
        if hasVoiceClone { score += 0.2 }
        if hasAvatar { score += 0.15 }
        return score
    }

    var isReady: Bool {
        hasSoulProfile && readinessScore >= 0.4
    }

    var allowedContacts: [UUID] {
        allowedContactIds.compactMap { UUID(uuidString: $0) }
    }

    func addAllowedContact(_ contactId: UUID) {
        let idString = contactId.uuidString
        if !allowedContactIds.contains(idString) {
            allowedContactIds.append(idString)
            updatedAt = Date()
        }
    }

    func removeAllowedContact(_ contactId: UUID) {
        allowedContactIds.removeAll { $0 == contactId.uuidString }
        updatedAt = Date()
    }

    func isContactAllowed(_ contactId: UUID) -> Bool {
        switch currentAccessMode {
        case .everyone:
            return true
        case .selectedContacts:
            return allowedContactIds.contains(contactId.uuidString)
        case .noOne:
            return false
        }
    }

    // MARK: - Conversation History

    var conversationHistory: [[String: Any]] {
        get {
            guard let data = conversationHistoryData,
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return array
        }
        set {
            conversationHistoryData = try? JSONSerialization.data(withJSONObject: newValue)
            updatedAt = Date()
        }
    }

    func addConversation(contactId: UUID, messages: [DigitalSelfMessage]) {
        var history = conversationHistory
        let conversation: [String: Any] = [
            "contactId": contactId.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "messages": messages.map { $0.toDictionary() }
        ]
        history.append(conversation)
        // Keep only last 50 conversations
        if history.count > 50 {
            history = Array(history.suffix(50))
        }
        conversationHistory = history
        totalConversations += 1
        totalMessages += messages.count
        lastInteractionDate = Date()
    }

    func updateComponentStatus(
        soulProfile: Bool? = nil,
        voiceClone: Bool? = nil,
        writingStyle: Bool? = nil,
        avatar: Bool? = nil
    ) {
        if let sp = soulProfile { hasSoulProfile = sp }
        if let vc = voiceClone { hasVoiceClone = vc }
        if let ws = writingStyle { hasWritingStyle = ws }
        if let av = avatar { hasAvatar = av }

        // Update status based on readiness
        if isReady && isEnabled {
            currentStatus = .active
        } else if isReady {
            currentStatus = .ready
        } else {
            currentStatus = .notReady
        }
        updatedAt = Date()
    }
}

// MARK: - Digital Self Status

enum DigitalSelfStatus: String, Codable {
    case notReady = "not_ready"
    case ready = "ready"
    case active = "active"
    case paused = "paused"

    var label: String {
        switch self {
        case .notReady: return String(localized: "digitalself.status.not_ready")
        case .ready: return String(localized: "digitalself.status.ready")
        case .active: return String(localized: "digitalself.status.active")
        case .paused: return String(localized: "digitalself.status.paused")
        }
    }

    var icon: String {
        switch self {
        case .notReady: return "circle.dashed"
        case .ready: return "checkmark.circle"
        case .active: return "person.crop.circle.badge.checkmark"
        case .paused: return "pause.circle"
        }
    }

    var color: String {
        switch self {
        case .notReady: return "secondary"
        case .ready: return "blue"
        case .active: return "green"
        case .paused: return "orange"
        }
    }
}

// MARK: - Access Mode

enum DigitalSelfAccessMode: String, CaseIterable, Codable {
    case everyone = "everyone"
    case selectedContacts = "selected_contacts"
    case noOne = "no_one"

    var label: String {
        switch self {
        case .everyone: return String(localized: "digitalself.access.everyone")
        case .selectedContacts: return String(localized: "digitalself.access.selected")
        case .noOne: return String(localized: "digitalself.access.no_one")
        }
    }

    var description: String {
        switch self {
        case .everyone: return String(localized: "digitalself.access.everyone.desc")
        case .selectedContacts: return String(localized: "digitalself.access.selected.desc")
        case .noOne: return String(localized: "digitalself.access.no_one.desc")
        }
    }
}

// MARK: - Personality Mode

enum DigitalSelfPersonalityMode: String, CaseIterable, Codable {
    case authentic = "authentic"
    case supportive = "supportive"
    case playful = "playful"
    case wise = "wise"

    var label: String {
        switch self {
        case .authentic: return String(localized: "digitalself.personality.authentic")
        case .supportive: return String(localized: "digitalself.personality.supportive")
        case .playful: return String(localized: "digitalself.personality.playful")
        case .wise: return String(localized: "digitalself.personality.wise")
        }
    }

    var description: String {
        switch self {
        case .authentic: return String(localized: "digitalself.personality.authentic.desc")
        case .supportive: return String(localized: "digitalself.personality.supportive.desc")
        case .playful: return String(localized: "digitalself.personality.playful.desc")
        case .wise: return String(localized: "digitalself.personality.wise.desc")
        }
    }

    var systemPromptAddition: String {
        switch self {
        case .authentic:
            return "Respond authentically, as you naturally would based on your personality and experiences."
        case .supportive:
            return "Be extra warm, supportive, and encouraging in your responses. Offer comfort and understanding."
        case .playful:
            return "Be lighthearted and playful. Use humor when appropriate while staying true to your personality."
        case .wise:
            return "Share wisdom and thoughtful insights. Draw from life experiences to offer guidance."
        }
    }
}

// MARK: - Digital Self Message

struct DigitalSelfMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var audioURL: URL?
    var isPlaying: Bool

    enum Role: String, Codable {
        case user
        case digitalSelf
    }

    init(role: Role, content: String, audioURL: URL? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.audioURL = audioURL
        self.isPlaying = false
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "role": role.rawValue,
            "content": content,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        if let url = audioURL {
            dict["audioURL"] = url.absoluteString
        }
        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) -> DigitalSelfMessage? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let roleString = dict["role"] as? String,
              let role = Role(rawValue: roleString),
              let content = dict["content"] as? String,
              let timestampString = dict["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
            return nil
        }

        var audioURL: URL? = nil
        if let urlString = dict["audioURL"] as? String {
            audioURL = URL(string: urlString)
        }

        return DigitalSelfMessage(id: id, role: role, content: content, timestamp: timestamp, audioURL: audioURL, isPlaying: false)
    }

    private init(id: UUID, role: Role, content: String, timestamp: Date, audioURL: URL?, isPlaying: Bool) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.audioURL = audioURL
        self.isPlaying = isPlaying
    }
}

// MARK: - Component Status

struct DigitalSelfComponentStatus {
    let name: String
    let icon: String
    let isReady: Bool
    let progress: Double
    let statusText: String
}
