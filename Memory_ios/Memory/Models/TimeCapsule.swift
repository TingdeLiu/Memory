import Foundation
import SwiftData

@Model
final class TimeCapsule {
    var id: UUID
    var unlockType: CapsuleUnlockType
    var isUnlocked: Bool
    var unlockedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Date unlock (P0)
    var unlockDate: Date?

    // MARK: - Location unlock (P1)
    var unlockLatitude: Double?
    var unlockLongitude: Double?
    var unlockRadius: Double?

    // MARK: - Event unlock (P2)
    var eventTargetDate: Date?
    var eventContactId: UUID?

    // MARK: - Relationship
    @Relationship(inverse: \MemoryEntry.timeCapsule)
    var memory: MemoryEntry?

    // MARK: - Plain-text storage

    var _plainUnlockLocationName: String?
    var _plainEventDescription: String?

    // MARK: - Encrypted storage (full mode)

    var _encryptedUnlockLocationName: String?
    var _encryptedEventDescription: String?

    // MARK: - Decryption Cache

    @Transient private var _cachedUnlockLocationName: String?
    @Transient private var _cachedEventDescription: String?

    func invalidateDecryptionCache() {
        _cachedUnlockLocationName = nil
        _cachedEventDescription = nil
    }

    // MARK: - Transparent accessors

    var unlockLocationName: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedUnlockLocationName {
                if let cached = _cachedUnlockLocationName { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id)
                _cachedUnlockLocationName = decrypted
                return decrypted
            }
            return _plainUnlockLocationName
        }
        set {
            _plainUnlockLocationName = newValue
            _cachedUnlockLocationName = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedUnlockLocationName = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedUnlockLocationName = nil
            }
        }
    }

    var eventDescription: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedEventDescription {
                if let cached = _cachedEventDescription { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id)
                _cachedEventDescription = decrypted
                return decrypted
            }
            return _plainEventDescription
        }
        set {
            _plainEventDescription = newValue
            _cachedEventDescription = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedEventDescription = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedEventDescription = nil
            }
        }
    }

    // MARK: - Computed

    var isReady: Bool {
        switch unlockType {
        case .date:
            guard let unlockDate else { return false }
            return Date() >= unlockDate
        case .location:
            return false // Requires geofence trigger
        case .event:
            return false // Requires manual trigger
        }
    }

    var countdownTarget: Date? {
        switch unlockType {
        case .date: return unlockDate
        case .location: return nil
        case .event: return eventTargetDate
        }
    }

    var conditionSummary: String {
        switch unlockType {
        case .date:
            if let date = unlockDate {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
            return String(localized: "capsule.condition.unknown")
        case .location:
            return unlockLocationName ?? String(localized: "capsule.condition.location")
        case .event:
            return eventDescription ?? String(localized: "capsule.condition.event")
        }
    }

    // MARK: - Init

    init(
        unlockType: CapsuleUnlockType = .date,
        unlockDate: Date? = nil,
        unlockLatitude: Double? = nil,
        unlockLongitude: Double? = nil,
        unlockRadius: Double? = 200,
        unlockLocationName: String? = nil,
        eventDescription: String? = nil,
        eventTargetDate: Date? = nil,
        eventContactId: UUID? = nil,
        memory: MemoryEntry? = nil
    ) {
        self.id = UUID()
        self.unlockType = unlockType
        self.isUnlocked = false
        self.unlockedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.unlockDate = unlockDate
        self.unlockLatitude = unlockLatitude
        self.unlockLongitude = unlockLongitude
        self.unlockRadius = unlockRadius
        self.eventTargetDate = eventTargetDate
        self.eventContactId = eventContactId
        self.memory = memory

        self._plainUnlockLocationName = unlockLocationName
        self._plainEventDescription = eventDescription
        self._encryptedUnlockLocationName = nil
        self._encryptedEventDescription = nil

        if EncryptionLevel.current == .full {
            if let unlockLocationName {
                self._encryptedUnlockLocationName = EncryptedFieldHelper.encryptString(unlockLocationName, recordId: self.id)
            }
            if let eventDescription {
                self._encryptedEventDescription = EncryptedFieldHelper.encryptString(eventDescription, recordId: self.id)
            }
        }
    }

    // MARK: - Unlock

    func unlock() {
        isUnlocked = true
        unlockedAt = Date()
        updatedAt = Date()
    }

    // MARK: - Migration helpers

    func encryptAllFields() {
        if let name = _plainUnlockLocationName {
            _encryptedUnlockLocationName = EncryptedFieldHelper.encryptString(name, recordId: id)
        }
        if let desc = _plainEventDescription {
            _encryptedEventDescription = EncryptedFieldHelper.encryptString(desc, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let encrypted = _encryptedUnlockLocationName, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainUnlockLocationName = decrypted
        }
        if let encrypted = _encryptedEventDescription, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainEventDescription = decrypted
        }
        _encryptedUnlockLocationName = nil
        _encryptedEventDescription = nil
    }
}

// MARK: - CapsuleUnlockType

enum CapsuleUnlockType: String, Codable, CaseIterable {
    case date
    case location
    case event

    var label: String {
        switch self {
        case .date: return String(localized: "capsule.type.date")
        case .location: return String(localized: "capsule.type.location")
        case .event: return String(localized: "capsule.type.event")
        }
    }

    var icon: String {
        switch self {
        case .date: return "calendar.badge.clock"
        case .location: return "mappin.and.ellipse"
        case .event: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .date: return String(localized: "capsule.type.date.description")
        case .location: return String(localized: "capsule.type.location.description")
        case .event: return String(localized: "capsule.type.event.description")
        }
    }
}
