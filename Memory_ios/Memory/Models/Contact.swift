import Foundation
import SwiftData
import SwiftUI

@Model
final class Contact {
    var id: UUID
    var relationship: Relationship
    var importSource: ImportSource
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Message.contact)
    var messages: [Message] = []

    // MARK: - Plain-text storage

    var _plainName: String
    var _plainAvatarData: Data?
    var _plainNotes: String
    var _plainSystemContactId: String?

    // MARK: - Encrypted storage (full mode)

    var _encryptedName: String?
    var _encryptedAvatarData: Data?
    var _encryptedNotes: String?
    var _encryptedSystemContactId: String?

    // MARK: - Decryption Cache (Performance Optimization)

    @Transient private var _cachedName: String?
    @Transient private var _cachedNotes: String?

    func invalidateDecryptionCache() {
        _cachedName = nil
        _cachedNotes = nil
    }

    // MARK: - Transparent accessors

    var name: String {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedName {
                if let cached = _cachedName { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) ?? _plainName
                _cachedName = decrypted
                return decrypted
            }
            return _plainName
        }
        set {
            _plainName = newValue
            _cachedName = newValue
            if EncryptionLevel.current == .full {
                _encryptedName = EncryptedFieldHelper.encryptString(newValue, recordId: id)
            }
        }
    }

    /// Load avatar data asynchronously to avoid blocking the main thread.
    func loadAvatarDataAsync() async -> Data? {
        let contact = self
        return await withCheckedContinuation { continuation in
            Task.detached {
                let data = contact.avatarData
                continuation.resume(returning: data)
            }
        }
    }

    var avatarData: Data? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedAvatarData {
                return EncryptedFieldHelper.decryptData(encrypted, recordId: id)
            }
            return _plainAvatarData
        }
        set {
            _plainAvatarData = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedAvatarData = EncryptedFieldHelper.encryptData(value, recordId: id)
            } else {
                _encryptedAvatarData = nil
            }
        }
    }

    var notes: String {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedNotes {
                if let cached = _cachedNotes { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) ?? _plainNotes
                _cachedNotes = decrypted
                return decrypted
            }
            return _plainNotes
        }
        set {
            _plainNotes = newValue
            _cachedNotes = newValue
            if EncryptionLevel.current == .full {
                _encryptedNotes = EncryptedFieldHelper.encryptString(newValue, recordId: id)
            }
        }
    }

    var systemContactId: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedSystemContactId {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainSystemContactId
        }
        set {
            _plainSystemContactId = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedSystemContactId = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedSystemContactId = nil
            }
        }
    }

    init(
        name: String,
        relationship: Relationship = .other,
        importSource: ImportSource = .manual,
        systemContactId: String? = nil,
        isFavorite: Bool = false,
        notes: String = ""
    ) {
        self.id = UUID()
        self.relationship = relationship
        self.importSource = importSource
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()

        self._plainName = name
        self._plainNotes = notes
        self._plainSystemContactId = systemContactId
        self._plainAvatarData = nil

        self._encryptedName = nil
        self._encryptedAvatarData = nil
        self._encryptedNotes = nil
        self._encryptedSystemContactId = nil

        if EncryptionLevel.current == .full {
            self._encryptedName = EncryptedFieldHelper.encryptString(name, recordId: self.id)
            self._encryptedNotes = EncryptedFieldHelper.encryptString(notes, recordId: self.id)
            if let systemContactId {
                self._encryptedSystemContactId = EncryptedFieldHelper.encryptString(systemContactId, recordId: self.id)
            }
        }
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt > $1.createdAt }
    }

    var latestMessage: Message? {
        messages.max(by: { $0.createdAt < $1.createdAt })
    }

    func messages(for condition: DeliveryCondition) -> [Message] {
        messages.filter { $0.deliveryCondition == condition }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var afterDeathMessageCount: Int {
        messages.filter { $0.deliveryCondition == .afterDeath }.count
    }

    // MARK: - Migration helpers

    func encryptAllFields() {
        _encryptedName = EncryptedFieldHelper.encryptString(_plainName, recordId: id)
        _encryptedNotes = EncryptedFieldHelper.encryptString(_plainNotes, recordId: id)
        if let a = _plainAvatarData {
            _encryptedAvatarData = EncryptedFieldHelper.encryptData(a, recordId: id)
        }
        if let s = _plainSystemContactId {
            _encryptedSystemContactId = EncryptedFieldHelper.encryptString(s, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let encrypted = _encryptedName, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainName = decrypted
        }
        if let encrypted = _encryptedNotes, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainNotes = decrypted
        }
        if let encrypted = _encryptedAvatarData, let decrypted = EncryptedFieldHelper.decryptData(encrypted, recordId: id) {
            _plainAvatarData = decrypted
        }
        if let encrypted = _encryptedSystemContactId, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainSystemContactId = decrypted
        }

        _encryptedName = nil
        _encryptedAvatarData = nil
        _encryptedNotes = nil
        _encryptedSystemContactId = nil
    }
}

enum Relationship: String, Codable, CaseIterable {
    case family
    case partner
    case friend
    case colleague
    case mentor
    case other

    var label: String {
        switch self {
        case .family: return String(localized: "relationship.family")
        case .partner: return String(localized: "relationship.partner")
        case .friend: return String(localized: "relationship.friend")
        case .colleague: return String(localized: "relationship.colleague")
        case .mentor: return String(localized: "relationship.mentor")
        case .other: return String(localized: "relationship.other")
        }
    }

    var icon: String {
        switch self {
        case .family: return "house.fill"
        case .partner: return "heart.fill"
        case .friend: return "person.2.fill"
        case .colleague: return "briefcase.fill"
        case .mentor: return "graduationcap.fill"
        case .other: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .family: return .orange
        case .partner: return .pink
        case .friend: return .blue
        case .colleague: return .purple
        case .mentor: return .green
        case .other: return .gray
        }
    }
}

enum ImportSource: String, Codable {
    case manual
    case systemContacts
}
