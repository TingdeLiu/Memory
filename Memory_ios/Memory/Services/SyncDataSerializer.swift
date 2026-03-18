import Foundation
import CryptoKit

/// Serializes SwiftData models to/from encrypted JSON for cloud sync (iCloud and Google Drive).
enum SyncDataSerializer {

    // MARK: - Serializable Models

    struct SerializedMemory: Codable {
        let id: UUID
        let title: String
        let content: String
        let type: String
        let tags: [String]
        let mood: String?
        let isPrivate: Bool
        let audioFilePath: String?
        let audioDuration: TimeInterval?
        let transcription: String?
        let videoFilePath: String?
        let videoDuration: TimeInterval?
        let createdAt: Date
        let updatedAt: Date
        // photoData and videoThumbnailData are stored as separate media files
    }

    struct SerializedContact: Codable {
        let id: UUID
        let name: String
        let relationship: String
        let importSource: String
        let systemContactId: String?
        let isFavorite: Bool
        let notes: String
        let createdAt: Date
        let updatedAt: Date
    }

    struct SerializedMessage: Codable {
        let id: UUID
        let content: String
        let type: String
        let deliveryCondition: String
        let deliveryDate: Date?
        let audioFilePath: String?
        let audioDuration: TimeInterval?
        let contactId: UUID?
        let createdAt: Date
        let updatedAt: Date
    }

    struct SerializedTimeCapsule: Codable {
        let id: UUID
        let unlockType: String
        let isUnlocked: Bool
        let unlockedAt: Date?
        let unlockDate: Date?
        let unlockLatitude: Double?
        let unlockLongitude: Double?
        let unlockRadius: Double?
        let unlockLocationName: String?
        let eventDescription: String?
        let eventTargetDate: Date?
        let eventContactId: UUID?
        let memoryId: UUID?
        let createdAt: Date
        let updatedAt: Date
    }

    struct SyncManifest: Codable {
        let version: Int
        let lastSync: Date
        let memories: [ManifestEntry]
        let contacts: [ManifestEntry]
        let messages: [ManifestEntry]
        let timeCapsules: [ManifestEntry]?
        let deletedIds: [UUID]
    }

    struct ManifestEntry: Codable {
        let id: UUID
        let updatedAt: Date
    }

    // MARK: - Serialize

    static func serialize(memory: MemoryEntry) -> SerializedMemory {
        SerializedMemory(
            id: memory.id,
            title: memory.title,
            content: memory.content,
            type: memory.type.rawValue,
            tags: memory.tags,
            mood: memory.mood?.rawValue,
            isPrivate: memory.isPrivate,
            audioFilePath: memory.audioFilePath,
            audioDuration: memory.audioDuration,
            transcription: memory.transcription,
            videoFilePath: memory.videoFilePath,
            videoDuration: memory.videoDuration,
            createdAt: memory.createdAt,
            updatedAt: memory.updatedAt
        )
    }

    static func serialize(contact: Contact) -> SerializedContact {
        SerializedContact(
            id: contact.id,
            name: contact.name,
            relationship: contact.relationship.rawValue,
            importSource: contact.importSource.rawValue,
            systemContactId: contact.systemContactId,
            isFavorite: contact.isFavorite,
            notes: contact.notes,
            createdAt: contact.createdAt,
            updatedAt: contact.updatedAt
        )
    }

    static func serialize(message: Message) -> SerializedMessage {
        SerializedMessage(
            id: message.id,
            content: message.content,
            type: message.type.rawValue,
            deliveryCondition: message.deliveryCondition.rawValue,
            deliveryDate: message.deliveryDate,
            audioFilePath: message.audioFilePath,
            audioDuration: message.audioDuration,
            contactId: message.contact?.id,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt
        )
    }

    static func serialize(capsule: TimeCapsule) -> SerializedTimeCapsule {
        SerializedTimeCapsule(
            id: capsule.id,
            unlockType: capsule.unlockType.rawValue,
            isUnlocked: capsule.isUnlocked,
            unlockedAt: capsule.unlockedAt,
            unlockDate: capsule.unlockDate,
            unlockLatitude: capsule.unlockLatitude,
            unlockLongitude: capsule.unlockLongitude,
            unlockRadius: capsule.unlockRadius,
            unlockLocationName: capsule.unlockLocationName,
            eventDescription: capsule.eventDescription,
            eventTargetDate: capsule.eventTargetDate,
            eventContactId: capsule.eventContactId,
            memoryId: capsule.memory?.id,
            createdAt: capsule.createdAt,
            updatedAt: capsule.updatedAt
        )
    }

    // MARK: - Encode to JSON

    static func encodeToJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    static func decodeFromJSON<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Encrypt / Decrypt for Cloud

    /// Serialize a value to JSON, then encrypt it for cloud storage.
    static func serializeAndEncrypt<T: Encodable>(_ value: T) throws -> Data {
        let json = try encodeToJSON(value)
        let key = try EncryptionHelper.masterKey()
        return try EncryptionHelper.encrypt(json, using: key)
    }

    /// Decrypt cloud data and deserialize from JSON.
    static func decryptAndDeserialize<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let key = try EncryptionHelper.masterKey()
        let json = try EncryptionHelper.decrypt(data, using: key)
        return try decodeFromJSON(json, as: type)
    }

    // MARK: - Manifest

    static func createManifest(
        memories: [MemoryEntry],
        contacts: [Contact],
        messages: [Message],
        timeCapsules: [TimeCapsule] = [],
        deletedIds: [UUID] = []
    ) -> SyncManifest {
        SyncManifest(
            version: 1,
            lastSync: Date(),
            memories: memories.map { ManifestEntry(id: $0.id, updatedAt: $0.updatedAt) },
            contacts: contacts.map { ManifestEntry(id: $0.id, updatedAt: $0.updatedAt) },
            messages: messages.map { ManifestEntry(id: $0.id, updatedAt: $0.updatedAt) },
            timeCapsules: timeCapsules.isEmpty ? nil : timeCapsules.map { ManifestEntry(id: $0.id, updatedAt: $0.updatedAt) },
            deletedIds: deletedIds
        )
    }
}
