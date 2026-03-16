import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var type: MessageType
    var deliveryCondition: DeliveryCondition
    var deliveryDate: Date?
    var audioDuration: TimeInterval?
    var createdAt: Date
    var updatedAt: Date

    var contact: Contact?

    // MARK: - Plain-text storage

    var _plainContent: String
    var _plainAudioFilePath: String?

    // MARK: - Encrypted storage (full mode)

    var _encryptedContent: String?
    var _encryptedAudioFilePath: String?

    // MARK: - Decryption Cache (Performance Optimization)

    @Transient private var _cachedContent: String?
    @Transient private var _cachedAudioFilePath: String?

    func invalidateDecryptionCache() {
        _cachedContent = nil
        _cachedAudioFilePath = nil
    }

    // MARK: - Transparent accessors

    var content: String {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedContent {
                if let cached = _cachedContent { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) ?? _plainContent
                _cachedContent = decrypted
                return decrypted
            }
            return _plainContent
        }
        set {
            _plainContent = newValue
            _cachedContent = newValue
            if EncryptionLevel.current == .full {
                _encryptedContent = EncryptedFieldHelper.encryptString(newValue, recordId: id)
            }
        }
    }

    var audioFilePath: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedAudioFilePath {
                if let cached = _cachedAudioFilePath { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id)
                _cachedAudioFilePath = decrypted
                return decrypted
            }
            return _plainAudioFilePath
        }
        set {
            _plainAudioFilePath = newValue
            _cachedAudioFilePath = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedAudioFilePath = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedAudioFilePath = nil
            }
        }
    }

    init(
        content: String = "",
        type: MessageType = .text,
        deliveryCondition: DeliveryCondition = .immediate,
        deliveryDate: Date? = nil,
        audioFilePath: String? = nil,
        audioDuration: TimeInterval? = nil,
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.deliveryCondition = deliveryCondition
        self.deliveryDate = deliveryDate
        self.audioDuration = audioDuration
        self.contact = contact
        self.createdAt = Date()
        self.updatedAt = Date()

        self._plainContent = content
        self._plainAudioFilePath = audioFilePath

        self._encryptedContent = nil
        self._encryptedAudioFilePath = nil

        if EncryptionLevel.current == .full {
            self._encryptedContent = EncryptedFieldHelper.encryptString(content, recordId: self.id)
            if let audioFilePath {
                self._encryptedAudioFilePath = EncryptedFieldHelper.encryptString(audioFilePath, recordId: self.id)
            }
        }
    }

    var isDeliverable: Bool {
        switch deliveryCondition {
        case .immediate:
            return true
        case .specificDate:
            guard let date = deliveryDate else { return false }
            return Date() >= date
        case .afterDeath:
            return false
        }
    }

    var statusLabel: String {
        switch deliveryCondition {
        case .immediate:
            return String(localized: "message.status.visible")
        case .specificDate:
            if let date = deliveryDate {
                if Date() >= date {
                    return String(localized: "message.status.delivered")
                }
                return String(localized: "message.status.scheduled")
            }
            return String(localized: "message.status.scheduled")
        case .afterDeath:
            return String(localized: "message.status.sealed")
        }
    }

    var statusColor: String {
        switch deliveryCondition {
        case .immediate: return "green"
        case .specificDate:
            if let date = deliveryDate, Date() >= date { return "green" }
            return "orange"
        case .afterDeath: return "purple"
        }
    }

    // MARK: - Migration helpers

    func encryptAllFields() {
        _encryptedContent = EncryptedFieldHelper.encryptString(_plainContent, recordId: id)
        if let a = _plainAudioFilePath {
            _encryptedAudioFilePath = EncryptedFieldHelper.encryptString(a, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let encrypted = _encryptedContent, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainContent = decrypted
        }
        if let encrypted = _encryptedAudioFilePath, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainAudioFilePath = decrypted
        }

        _encryptedContent = nil
        _encryptedAudioFilePath = nil
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text
    case audio
}

enum DeliveryCondition: String, Codable, CaseIterable {
    case immediate
    case specificDate
    case afterDeath

    var label: String {
        switch self {
        case .immediate: return String(localized: "delivery.immediate.label")
        case .specificDate: return String(localized: "delivery.specificDate.label")
        case .afterDeath: return String(localized: "delivery.afterDeath.label")
        }
    }

    var icon: String {
        switch self {
        case .immediate: return "eye"
        case .specificDate: return "calendar"
        case .afterDeath: return "infinity"
        }
    }

    var description: String {
        switch self {
        case .immediate: return String(localized: "delivery.immediate.description")
        case .specificDate: return String(localized: "delivery.specificDate.description")
        case .afterDeath: return String(localized: "delivery.afterDeath.description")
        }
    }
}
