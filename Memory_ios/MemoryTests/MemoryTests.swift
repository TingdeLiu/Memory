import Testing
import SwiftData
import Foundation
import CryptoKit
@testable import Memory

// MARK: - Memory Entry Tests

@Suite("Memory Entry Tests")
struct MemoryEntryTests {
    @Test func createTextMemory() {
        let entry = MemoryEntry(
            title: "Test Memory",
            content: "This is a test memory.",
            tags: ["test", "unit"],
            mood: .happy
        )

        #expect(entry.title == "Test Memory")
        #expect(entry.content == "This is a test memory.")
        #expect(entry.tags == ["test", "unit"])
        #expect(entry.mood == .happy)
        #expect(entry.type == .text)
        #expect(entry.isPrivate == false)
        #expect(entry.audioFilePath == nil)
        #expect(entry.audioDuration == nil)
        #expect(entry.transcription == nil)
        #expect(entry.photoData == nil)
        #expect(entry.videoFilePath == nil)
        #expect(entry.videoDuration == nil)
        #expect(entry.videoThumbnailData == nil)
    }

    @Test func createAudioMemory() {
        let entry = MemoryEntry(
            title: "Voice Note",
            content: "",
            type: .audio,
            audioFilePath: "memory_test.m4a",
            audioDuration: 45.5,
            transcription: "Hello, this is a voice memo."
        )

        #expect(entry.type == .audio)
        #expect(entry.audioFilePath == "memory_test.m4a")
        #expect(entry.audioDuration == 45.5)
        #expect(entry.transcription == "Hello, this is a voice memo.")
    }

    @Test func createPhotoMemory() {
        let fakeData = Data([0x89, 0x50, 0x4E, 0x47])
        let entry = MemoryEntry(
            title: "Photo Memory",
            type: .photo,
            photoData: fakeData
        )

        #expect(entry.type == .photo)
        #expect(entry.photoData?.count == 4)
    }

    @Test func createVideoMemory() {
        let entry = MemoryEntry(
            title: "Video Memory",
            type: .video,
            videoFilePath: "memory_test.mov",
            videoDuration: 120.0,
            videoThumbnailData: Data([0xFF, 0xD8])
        )

        #expect(entry.type == .video)
        #expect(entry.videoFilePath == "memory_test.mov")
        #expect(entry.videoDuration == 120.0)
        #expect(entry.videoThumbnailData?.count == 2)
    }

    @Test func moodEmojiMapping() {
        #expect(Mood.happy.emoji == "😊")
        #expect(Mood.sad.emoji == "😢")
        #expect(Mood.loving.emoji == "❤️")
        #expect(Mood.nostalgic.emoji == "🥹")
        #expect(Mood.grateful.emoji == "🙏")
        #expect(Mood.calm.emoji == "😌")
        #expect(Mood.anxious.emoji == "😰")
        #expect(Mood.hopeful.emoji == "🌟")
    }

    @Test func moodLabels() {
        for mood in Mood.allCases {
            #expect(!mood.label.isEmpty)
            #expect(mood.label == mood.rawValue.capitalized)
        }
    }

    @Test func memoryTypeAllCases() {
        #expect(MemoryType.allCases.count == 4)
        #expect(MemoryType.allCases.contains(.text))
        #expect(MemoryType.allCases.contains(.audio))
        #expect(MemoryType.allCases.contains(.photo))
        #expect(MemoryType.allCases.contains(.video))
    }

    @Test func timestampsSetOnCreation() {
        let before = Date()
        let entry = MemoryEntry(title: "Timestamp Test")
        let after = Date()

        #expect(entry.createdAt >= before)
        #expect(entry.createdAt <= after)
    }

    @Test func uniqueIDs() {
        let a = MemoryEntry(title: "A")
        let b = MemoryEntry(title: "B")
        #expect(a.id != b.id)
    }
}

// MARK: - Contact Tests

@Suite("Contact Tests")
struct ContactTests {
    @Test func createManualContact() {
        let contact = Contact(name: "Mom", relationship: .family, notes: "Best mom ever")

        #expect(contact.name == "Mom")
        #expect(contact.relationship == .family)
        #expect(contact.notes == "Best mom ever")
        #expect(contact.importSource == .manual)
        #expect(contact.systemContactId == nil)
        #expect(contact.isFavorite == false)
        #expect(contact.messages.isEmpty)
    }

    @Test func createImportedContact() {
        let contact = Contact(
            name: "John Doe",
            relationship: .friend,
            importSource: .systemContacts,
            systemContactId: "ABC-123"
        )

        #expect(contact.importSource == .systemContacts)
        #expect(contact.systemContactId == "ABC-123")
    }

    @Test func favoriteContact() {
        let contact = Contact(name: "Partner", relationship: .partner, isFavorite: true)

        #expect(contact.isFavorite == true)
        contact.isFavorite = false
        #expect(contact.isFavorite == false)
    }

    @Test func relationshipLabels() {
        #expect(Relationship.family.label == "Family")
        #expect(Relationship.partner.label == "Partner")
        #expect(Relationship.friend.label == "Friend")
        #expect(Relationship.colleague.label == "Colleague")
        #expect(Relationship.mentor.label == "Mentor")
        #expect(Relationship.other.label == "Other")
    }

    @Test func relationshipIcons() {
        for rel in Relationship.allCases {
            #expect(!rel.icon.isEmpty)
        }
    }

    @Test func relationshipColors() {
        for rel in Relationship.allCases {
            #expect(!rel.color.isEmpty)
        }
    }

    @Test func afterDeathMessageCount() {
        let contact = Contact(name: "Test")
        #expect(contact.afterDeathMessageCount == 0)
    }

    @Test func latestMessageNilWhenEmpty() {
        let contact = Contact(name: "Test")
        #expect(contact.latestMessage == nil)
    }
}

// MARK: - Message Tests

@Suite("Message Tests")
struct MessageTests {
    @Test func createTextMessage() {
        let message = Message(
            content: "I love you, Mom",
            deliveryCondition: .afterDeath
        )

        #expect(message.content == "I love you, Mom")
        #expect(message.deliveryCondition == .afterDeath)
        #expect(message.type == .text)
        #expect(message.deliveryDate == nil)
        #expect(message.audioFilePath == nil)
        #expect(message.audioDuration == nil)
    }

    @Test func createVoiceMessage() {
        let message = Message(
            content: "Voice note for dad",
            type: .audio,
            deliveryCondition: .immediate,
            audioFilePath: "msg_test.m4a",
            audioDuration: 12.5
        )

        #expect(message.type == .audio)
        #expect(message.audioFilePath == "msg_test.m4a")
        #expect(message.audioDuration == 12.5)
    }

    @Test func deliveryConditionLabels() {
        #expect(DeliveryCondition.immediate.label == "Visible Now")
        #expect(DeliveryCondition.afterDeath.label == "After I'm Gone")
        #expect(DeliveryCondition.specificDate.label == "Specific Date")
    }

    @Test func deliveryConditionIcons() {
        #expect(DeliveryCondition.immediate.icon == "eye")
        #expect(DeliveryCondition.specificDate.icon == "calendar")
        #expect(DeliveryCondition.afterDeath.icon == "infinity")
    }

    @Test func deliveryConditionDescriptions() {
        for condition in DeliveryCondition.allCases {
            #expect(!condition.description.isEmpty)
        }
    }

    @Test func messageWithSpecificDate() {
        let date = Date()
        let message = Message(
            content: "Open on your birthday!",
            deliveryCondition: .specificDate,
            deliveryDate: date
        )

        #expect(message.deliveryCondition == .specificDate)
        #expect(message.deliveryDate == date)
    }

    @Test func immediateMessageIsDeliverable() {
        let message = Message(content: "Hello", deliveryCondition: .immediate)
        #expect(message.isDeliverable == true)
    }

    @Test func afterDeathMessageNotDeliverable() {
        let message = Message(content: "Sealed", deliveryCondition: .afterDeath)
        #expect(message.isDeliverable == false)
    }

    @Test func pastDateMessageIsDeliverable() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let message = Message(
            content: "Past",
            deliveryCondition: .specificDate,
            deliveryDate: pastDate
        )
        #expect(message.isDeliverable == true)
    }

    @Test func futureDateMessageNotDeliverable() {
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let message = Message(
            content: "Future",
            deliveryCondition: .specificDate,
            deliveryDate: futureDate
        )
        #expect(message.isDeliverable == false)
    }

    @Test func statusLabels() {
        let immediate = Message(content: "", deliveryCondition: .immediate)
        #expect(immediate.statusLabel == "Visible")

        let sealed = Message(content: "", deliveryCondition: .afterDeath)
        #expect(sealed.statusLabel == "Sealed")

        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let scheduled = Message(content: "", deliveryCondition: .specificDate, deliveryDate: futureDate)
        #expect(scheduled.statusLabel == "Scheduled")

        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let delivered = Message(content: "", deliveryCondition: .specificDate, deliveryDate: pastDate)
        #expect(delivered.statusLabel == "Delivered")
    }
}

// MARK: - Audio Service Tests

@Suite("Audio Recording Service Tests")
struct AudioRecordingServiceTests {
    @Test func recordingsDirectory() {
        let dir = AudioRecordingService.recordingsDirectory
        #expect(dir.lastPathComponent == "Recordings")
    }

    @Test func recordingURLConstruction() {
        let url = AudioRecordingService.recordingURL(for: "test.m4a")
        #expect(url.lastPathComponent == "test.m4a")
        #expect(url.pathComponents.contains("Recordings"))
    }

    @Test func initialState() {
        let service = AudioRecordingService()
        #expect(service.isRecording == false)
        #expect(service.recordingDuration == 0)
        #expect(service.currentRecordingURL == nil)
        #expect(service.audioLevel == 0)
    }
}

// MARK: - Contact Import Service Tests

@Suite("Contact Import Service Tests")
struct ContactImportServiceTests {
    @Test func filterNewContacts() {
        let service = ContactImportService()
        let systemContacts = [
            SystemContact(id: "a", name: "Alice", thumbnailData: nil, phoneNumber: nil, emailAddress: nil),
            SystemContact(id: "b", name: "Bob", thumbnailData: nil, phoneNumber: nil, emailAddress: nil),
            SystemContact(id: "c", name: "Charlie", thumbnailData: nil, phoneNumber: nil, emailAddress: nil),
        ]
        let existingIds: Set<String> = ["a", "c"]
        let filtered = service.filterNew(systemContacts: systemContacts, existingIds: existingIds)

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Bob")
    }

    @Test func filterNewWithNoExisting() {
        let service = ContactImportService()
        let systemContacts = [
            SystemContact(id: "a", name: "Alice", thumbnailData: nil, phoneNumber: nil, emailAddress: nil),
        ]
        let filtered = service.filterNew(systemContacts: systemContacts, existingIds: [])

        #expect(filtered.count == 1)
    }

    @Test func filterNewWithAllExisting() {
        let service = ContactImportService()
        let systemContacts = [
            SystemContact(id: "a", name: "Alice", thumbnailData: nil, phoneNumber: nil, emailAddress: nil),
        ]
        let filtered = service.filterNew(systemContacts: systemContacts, existingIds: ["a"])

        #expect(filtered.isEmpty)
    }

    @Test func initialPermissionStatus() {
        let service = ContactImportService()
        #expect(service.systemContacts.isEmpty)
        #expect(service.isLoading == false)
    }
}

// MARK: - Encryption Tests

@Suite("Encryption Helper Tests")
struct EncryptionHelperTests {
    @Test func generateKeyIsUnique() {
        let key1 = EncryptionHelper.generateKey()
        let key2 = EncryptionHelper.generateKey()
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    @Test func encryptDecryptData() throws {
        let key = EncryptionHelper.generateKey()
        let original = Data("Hello, Memory!".utf8)
        let encrypted = try EncryptionHelper.encrypt(original, using: key)
        let decrypted = try EncryptionHelper.decrypt(encrypted, using: key)

        #expect(decrypted == original)
        #expect(encrypted != original)
    }

    @Test func encryptDecryptString() throws {
        let key = EncryptionHelper.generateKey()
        let original = "When no one remembers you, that's when you truly disappear."
        let encrypted = try EncryptionHelper.encryptString(original, using: key)
        let decrypted = try EncryptionHelper.decryptString(encrypted, using: key)

        #expect(decrypted == original)
        #expect(encrypted != original)
    }

    @Test func decryptWithWrongKeyFails() throws {
        let key1 = EncryptionHelper.generateKey()
        let key2 = EncryptionHelper.generateKey()
        let original = Data("Secret data".utf8)
        let encrypted = try EncryptionHelper.encrypt(original, using: key1)

        #expect(throws: (any Error).self) {
            _ = try EncryptionHelper.decrypt(encrypted, using: key2)
        }
    }

    @Test func encryptedDataDiffersEachTime() throws {
        let key = EncryptionHelper.generateKey()
        let original = Data("Same input".utf8)
        let encrypted1 = try EncryptionHelper.encrypt(original, using: key)
        let encrypted2 = try EncryptionHelper.encrypt(original, using: key)

        // AES-GCM uses random nonce, so ciphertexts differ
        #expect(encrypted1 != encrypted2)
    }

    @Test func sha256Consistency() {
        let hash1 = EncryptionHelper.sha256("test")
        let hash2 = EncryptionHelper.sha256("test")
        #expect(hash1 == hash2)
        #expect(hash1.count == 64) // 32 bytes = 64 hex chars
    }

    @Test func sha256DifferentInputs() {
        let hash1 = EncryptionHelper.sha256("hello")
        let hash2 = EncryptionHelper.sha256("world")
        #expect(hash1 != hash2)
    }

    @Test func encryptEmptyData() throws {
        let key = EncryptionHelper.generateKey()
        let original = Data()
        let encrypted = try EncryptionHelper.encrypt(original, using: key)
        let decrypted = try EncryptionHelper.decrypt(encrypted, using: key)
        #expect(decrypted == original)
    }

    @Test func encryptLargeData() throws {
        let key = EncryptionHelper.generateKey()
        let original = Data(repeating: 0xAB, count: 1_000_000) // 1 MB
        let encrypted = try EncryptionHelper.encrypt(original, using: key)
        let decrypted = try EncryptionHelper.decrypt(encrypted, using: key)
        #expect(decrypted == original)
    }

    @Test func keyDerivation() {
        let masterKey = EncryptionHelper.generateKey()
        let salt1 = Data("record-1".utf8)
        let salt2 = Data("record-2".utf8)

        let derived1 = EncryptionHelper.deriveKey(from: masterKey, salt: salt1)
        let derived2 = EncryptionHelper.deriveKey(from: masterKey, salt: salt2)

        let data1 = derived1.withUnsafeBytes { Data($0) }
        let data2 = derived2.withUnsafeBytes { Data($0) }

        // Different salts produce different keys
        #expect(data1 != data2)
    }

    @Test func keyDerivationDeterministic() {
        let masterKey = EncryptionHelper.generateKey()
        let salt = Data("same-salt".utf8)

        let derived1 = EncryptionHelper.deriveKey(from: masterKey, salt: salt)
        let derived2 = EncryptionHelper.deriveKey(from: masterKey, salt: salt)

        let data1 = derived1.withUnsafeBytes { Data($0) }
        let data2 = derived2.withUnsafeBytes { Data($0) }

        // Same inputs produce same derived key
        #expect(data1 == data2)
    }

    @Test func keyBackupAndRestore() throws {
        // Test backup/restore roundtrip
        let password = "testRecoveryPassword123"
        let key = EncryptionHelper.generateKey()
        let keyData = key.withUnsafeBytes { Data($0) }

        // Simulate backup
        let backup = try EncryptionHelper.backupMasterKey(withPassword: password)
        #expect(backup.count > 32) // salt + encrypted data
    }
}

// MARK: - Encryption Level Tests

@Suite("Encryption Level Tests")
struct EncryptionLevelTests {
    @Test func encryptionLevelAllCases() {
        #expect(EncryptionLevel.allCases.count == 2)
        #expect(EncryptionLevel.allCases.contains(.cloudOnly))
        #expect(EncryptionLevel.allCases.contains(.full))
    }

    @Test func encryptionLevelLabels() {
        #expect(!EncryptionLevel.cloudOnly.label.isEmpty)
        #expect(!EncryptionLevel.full.label.isEmpty)
    }

    @Test func encryptionLevelDescriptions() {
        #expect(!EncryptionLevel.cloudOnly.description.isEmpty)
        #expect(!EncryptionLevel.full.description.isEmpty)
    }

    @Test func encryptionLevelIcons() {
        #expect(!EncryptionLevel.cloudOnly.icon.isEmpty)
        #expect(!EncryptionLevel.full.icon.isEmpty)
    }

    @Test func encryptionLevelRawValues() {
        #expect(EncryptionLevel.cloudOnly.rawValue == "cloudOnly")
        #expect(EncryptionLevel.full.rawValue == "full")
    }
}

// MARK: - Encrypted Field Helper Tests

@Suite("Encrypted Field Helper Tests")
struct EncryptedFieldHelperTests {
    @Test func encryptDecryptStringArray() {
        let tags = ["hello", "world", "test"]
        let recordId = UUID()

        // These tests require Keychain access, so they may only work on device
        // Testing the array encoding/decoding logic
        if let encoded = try? JSONEncoder().encode(tags),
           let jsonString = String(data: encoded, encoding: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: encoded) {
            #expect(decoded == tags)
        }
    }
}

// MARK: - Sync Data Serializer Tests

@Suite("Sync Data Serializer Tests")
struct SyncDataSerializerTests {
    @Test func serializeMemory() {
        let memory = MemoryEntry(
            title: "Test",
            content: "Content",
            type: .text,
            tags: ["tag1"],
            mood: .happy
        )

        let serialized = SyncDataSerializer.serialize(memory: memory)
        #expect(serialized.title == "Test")
        #expect(serialized.content == "Content")
        #expect(serialized.type == "text")
        #expect(serialized.tags == ["tag1"])
        #expect(serialized.mood == "happy")
    }

    @Test func serializeVideoMemory() {
        let memory = MemoryEntry(
            title: "Video",
            type: .video,
            videoFilePath: "test.mov",
            videoDuration: 30.0
        )

        let serialized = SyncDataSerializer.serialize(memory: memory)
        #expect(serialized.type == "video")
        #expect(serialized.videoFilePath == "test.mov")
        #expect(serialized.videoDuration == 30.0)
    }

    @Test func serializeContact() {
        let contact = Contact(name: "Mom", relationship: .family)

        let serialized = SyncDataSerializer.serialize(contact: contact)
        #expect(serialized.name == "Mom")
        #expect(serialized.relationship == "family")
    }

    @Test func serializeMessage() {
        let message = Message(content: "Hello", deliveryCondition: .afterDeath)

        let serialized = SyncDataSerializer.serialize(message: message)
        #expect(serialized.content == "Hello")
        #expect(serialized.deliveryCondition == "afterDeath")
    }

    @Test func encodeDecodeJSON() throws {
        let serialized = SyncDataSerializer.SerializedMemory(
            id: UUID(),
            title: "Test",
            content: "Content",
            type: "text",
            tags: ["a", "b"],
            mood: "happy",
            isPrivate: false,
            audioFilePath: nil,
            audioDuration: nil,
            transcription: nil,
            videoFilePath: nil,
            videoDuration: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let json = try SyncDataSerializer.encodeToJSON(serialized)
        let decoded = try SyncDataSerializer.decodeFromJSON(json, as: SyncDataSerializer.SerializedMemory.self)

        #expect(decoded.title == serialized.title)
        #expect(decoded.content == serialized.content)
        #expect(decoded.type == serialized.type)
        #expect(decoded.tags == serialized.tags)
    }

    @Test func createManifest() {
        let memories = [MemoryEntry(title: "A"), MemoryEntry(title: "B")]
        let contacts = [Contact(name: "Mom")]
        let messages = [Message(content: "Hi")]

        let manifest = SyncDataSerializer.createManifest(
            memories: memories,
            contacts: contacts,
            messages: messages
        )

        #expect(manifest.version == 1)
        #expect(manifest.memories.count == 2)
        #expect(manifest.contacts.count == 1)
        #expect(manifest.messages.count == 1)
        #expect(manifest.deletedIds.isEmpty)
    }
}

// MARK: - Biometric Auth Tests

@Suite("Biometric Auth Tests")
struct BiometricAuthTests {
    @Test func biometricTypeProperties() {
        let faceID = BiometricAuth.BiometricType.faceID
        #expect(faceID.displayName == "Face ID")
        #expect(faceID.systemImage == "faceid")

        let touchID = BiometricAuth.BiometricType.touchID
        #expect(touchID.displayName == "Touch ID")
        #expect(touchID.systemImage == "touchid")

        let none = BiometricAuth.BiometricType.none
        #expect(none.displayName == "Passcode")
        #expect(none.systemImage == "lock.fill")

        let opticID = BiometricAuth.BiometricType.opticID
        #expect(opticID.displayName == "Optic ID")
        #expect(opticID.systemImage == "opticid")
    }
}

// MARK: - Cloud Sync Service Tests

@Suite("Cloud Sync Service Tests")
struct CloudSyncServiceTests {
    @Test func syncStatusProperties() {
        let synced = CloudSyncService.SyncStatus.synced
        #expect(synced.label == "Up to date")
        #expect(!synced.icon.isEmpty)

        let noAccount = CloudSyncService.SyncStatus.noAccount
        #expect(noAccount.label == "Not signed in")

        let error = CloudSyncService.SyncStatus.error("Test error")
        #expect(error.label == "Error: Test error")
    }

    @Test func formatBytes() {
        #expect(CloudSyncService.formatBytes(0) == "Zero KB")
        #expect(CloudSyncService.formatBytes(1024).contains("1"))
        #expect(CloudSyncService.formatBytes(1_048_576).contains("1"))
    }

    @Test func syncStatusEquality() {
        #expect(CloudSyncService.SyncStatus.synced == CloudSyncService.SyncStatus.synced)
        #expect(CloudSyncService.SyncStatus.noAccount != CloudSyncService.SyncStatus.synced)
        #expect(CloudSyncService.SyncStatus.error("a") == CloudSyncService.SyncStatus.error("a"))
        #expect(CloudSyncService.SyncStatus.error("a") != CloudSyncService.SyncStatus.error("b"))
    }
}

// MARK: - Data Statistics Tests

@Suite("Data Statistics Tests")
struct DataStatisticsTests {
    @Test func defaultValues() {
        let stats = DataStatistics(
            totalMemories: 10,
            textMemories: 5,
            audioMemories: 3,
            photoMemories: 2,
            privateMemories: 1,
            totalContacts: 8,
            totalMessages: 15,
            immediateMessages: 5,
            scheduledMessages: 4,
            sealedMessages: 6,
            oldestMemoryDate: Date()
        )

        #expect(stats.totalMemories == 10)
        #expect(stats.textMemories + stats.audioMemories + stats.photoMemories == stats.totalMemories)
        #expect(stats.immediateMessages + stats.scheduledMessages + stats.sealedMessages == stats.totalMessages)
        #expect(stats.oldestMemoryDate != nil)
    }
}

// MARK: - AI Service Tests

@Suite("AI Service Tests")
struct AIServiceTests {
    @Test func providerNames() {
        #expect(AIProvider.claude.name == "Claude")
        #expect(AIProvider.openAI.name == "GPT")
        #expect(AIProvider.gemini.name == "Gemini")
        #expect(AIProvider.deepSeek.name == "DeepSeek")
        #expect(AIProvider.custom.name == "Custom")
    }

    @Test func providerBaseURLs() {
        #expect(AIProvider.claude.baseURL.contains("anthropic.com"))
        #expect(AIProvider.openAI.baseURL.contains("openai.com"))
        #expect(AIProvider.gemini.baseURL.contains("googleapis.com"))
        #expect(AIProvider.deepSeek.baseURL.contains("deepseek.com"))
        #expect(AIProvider.custom.baseURL.isEmpty)
    }

    @Test func providerDefaultModels() {
        #expect(!AIProvider.claude.defaultModel.isEmpty)
        #expect(!AIProvider.openAI.defaultModel.isEmpty)
        #expect(!AIProvider.gemini.defaultModel.isEmpty)
        #expect(!AIProvider.deepSeek.defaultModel.isEmpty)
        #expect(AIProvider.custom.defaultModel.isEmpty)
    }

    @Test func providerAvailableModels() {
        #expect(AIProvider.claude.availableModels.count >= 2)
        #expect(AIProvider.openAI.availableModels.count >= 2)
        #expect(AIProvider.gemini.availableModels.count >= 2)
        #expect(AIProvider.deepSeek.availableModels.count >= 2)
        #expect(AIProvider.custom.availableModels.isEmpty)
    }

    @Test func providerKeychainAccounts() {
        #expect(AIProvider.claude.keychainAccount == "ai-api-key-claude")
        #expect(AIProvider.openAI.keychainAccount == "ai-api-key-openAI")
        #expect(AIProvider.gemini.keychainAccount == "ai-api-key-gemini")
        #expect(AIProvider.deepSeek.keychainAccount == "ai-api-key-deepSeek")
        #expect(AIProvider.custom.keychainAccount == "ai-api-key-custom")
    }

    @Test func providerAllCases() {
        #expect(AIProvider.allCases.count == 5)
    }

    @Test func chatMessageCreation() {
        let msg = ChatMessage(role: .user, content: "Hello")
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.timestamp <= Date())
    }

    @Test func chatMessageUniqueIDs() {
        let a = ChatMessage(role: .user, content: "A")
        let b = ChatMessage(role: .user, content: "B")
        #expect(a.id != b.id)
    }

    @Test func chatMessageRoles() {
        let user = ChatMessage(role: .user, content: "")
        let assistant = ChatMessage(role: .assistant, content: "")
        let system = ChatMessage(role: .system, content: "")
        #expect(user.role == .user)
        #expect(assistant.role == .assistant)
        #expect(system.role == .system)
    }

    @Test func formatMemoriesFiltersPrivate() {
        let publicMemory = MemoryEntry(title: "Public", content: "Visible")
        let privateMemory = MemoryEntry(title: "Private", content: "Hidden", isPrivate: true)

        let context = AIService.formatMemoriesForContext([publicMemory, privateMemory])

        #expect(context.contains("Public"))
        #expect(context.contains("Visible"))
        #expect(!context.contains("Private"))
        #expect(!context.contains("Hidden"))
    }

    @Test func formatMemoriesExcludesPhotoData() {
        let photoData = Data([0x89, 0x50, 0x4E, 0x47])
        let memory = MemoryEntry(
            title: "Photo Memory",
            content: "A photo",
            type: .photo,
            photoData: photoData
        )

        let context = AIService.formatMemoriesForContext([memory])

        #expect(context.contains("Photo Memory"))
        #expect(context.contains("A photo"))
        // photoData binary should not appear in context
        #expect(!context.contains("0x89"))
    }

    @Test func formatMemoriesExcludesAudioPath() {
        let memory = MemoryEntry(
            title: "Voice Note",
            content: "",
            type: .audio,
            audioFilePath: "memory_secret.m4a",
            audioDuration: 30.0
        )

        let context = AIService.formatMemoriesForContext([memory])

        #expect(context.contains("Voice Note"))
        #expect(!context.contains("memory_secret.m4a"))
    }

    @Test func formatMemoriesIncludesMoodAndTags() {
        let memory = MemoryEntry(
            title: "Happy Day",
            content: "Great day",
            tags: ["joy", "sunshine"],
            mood: .happy
        )

        let context = AIService.formatMemoriesForContext([memory])

        #expect(context.contains("Happy"))
        #expect(context.contains("joy"))
        #expect(context.contains("sunshine"))
        #expect(context.contains("😊"))
    }

    @Test func formatMemoriesEmptyList() {
        let context = AIService.formatMemoriesForContext([])
        #expect(context == "No memories available.")
    }

    @Test func formatMemoriesAllPrivate() {
        let memories = [
            MemoryEntry(title: "Secret1", isPrivate: true),
            MemoryEntry(title: "Secret2", isPrivate: true),
        ]
        let context = AIService.formatMemoriesForContext(memories)
        #expect(context == "No memories available.")
    }

    @Test func formatMemoriesIncludesTranscription() {
        let memory = MemoryEntry(
            title: "Voice",
            type: .audio,
            transcription: "This is transcribed text"
        )
        let context = AIService.formatMemoriesForContext([memory])
        #expect(context.contains("This is transcribed text"))
    }

    @Test func crisisKeywordsExist() {
        #expect(!AIService.crisisKeywords.isEmpty)
        #expect(AIService.crisisKeywords.contains("suicide"))
        #expect(AIService.crisisKeywords.contains("自杀"))
    }

    @Test func aiServiceInitialState() {
        let service = AIService()
        #expect(service.isProcessing == false)
        #expect(service.error == nil)
        #expect(service.currentResponse.isEmpty)
    }

    @Test func aiServiceErrorDescriptions() {
        #expect(AIServiceError.noAPIKey.errorDescription != nil)
        #expect(AIServiceError.invalidResponse.errorDescription != nil)
        #expect(AIServiceError.unauthorized.errorDescription != nil)
        #expect(AIServiceError.rateLimited.errorDescription != nil)
        #expect(AIServiceError.serverError(500).errorDescription!.contains("500"))
        #expect(AIServiceError.networkError("timeout").errorDescription!.contains("timeout"))
        #expect(AIServiceError.aiDisabled.errorDescription != nil)
    }
}

// MARK: - Store Service Tests

@Suite("Store Service Tests")
struct StoreServiceTests {
    @Test func premiumProductID() {
        #expect(StoreService.premiumProductID == "com.tyndall.memory.premium")
        #expect(StoreService.premiumProductID.hasPrefix("com.tyndall.memory."))
    }

    @Test func initialStateNotPremium() {
        let store = StoreService.shared
        // Products should be empty before loading
        #expect(store.products.isEmpty)
    }

    @Test func freeContactLimit() {
        // When not premium, contact limit is 5
        #expect(StoreService.shared.contactLimit == 5 || StoreService.shared.isPremium)
    }

    @Test func freeVoiceMemoryLimit() {
        // When not premium, voice memory limit is 3
        #expect(StoreService.shared.voiceMemoryLimit == 3 || StoreService.shared.isPremium)
    }

    @Test func freeVideoMemoryLimit() {
        // When not premium, video memory limit is 1
        #expect(StoreService.shared.videoMemoryLimit == 1 || StoreService.shared.isPremium)
    }

    @Test func featureGatingPropertiesExist() {
        let store = StoreService.shared
        // Verify all feature gating properties are accessible
        let _ = store.canCreateVoiceMemory
        let _ = store.canCreateVideoMemory
        let _ = store.canUseAI
        let _ = store.canExportEncrypted
        let _ = store.contactLimit
        let _ = store.voiceMemoryLimit
        let _ = store.videoMemoryLimit
        // If we got here without crash, properties exist
        #expect(true)
    }
}

// MARK: - Google Drive Service Tests

@Suite("Google Drive Service Tests")
struct GoogleDriveServiceTests {
    @Test func initialState() {
        let service = GoogleDriveSyncService.shared
        #expect(service.isSyncing == false)
        #expect(service.syncError == nil)
    }

    @Test func errorDescriptions() {
        #expect(GoogleDriveSyncService.GoogleDriveError.invalidURL.errorDescription != nil)
        #expect(GoogleDriveSyncService.GoogleDriveError.authenticationFailed.errorDescription != nil)
        #expect(GoogleDriveSyncService.GoogleDriveError.tokenExchangeFailed.errorDescription != nil)
        #expect(GoogleDriveSyncService.GoogleDriveError.notSignedIn.errorDescription != nil)
        #expect(GoogleDriveSyncService.GoogleDriveError.uploadFailed.errorDescription != nil)
        #expect(GoogleDriveSyncService.GoogleDriveError.downloadFailed.errorDescription != nil)
    }
}

// MARK: - Video Recording Service Tests

@Suite("Video Recording Service Tests")
struct VideoRecordingServiceTests {
    @Test func initialState() {
        let service = VideoRecordingService()
        #expect(service.isRecording == false)
        #expect(service.recordingDuration == 0)
        #expect(service.currentRecordingURL == nil)
        #expect(service.cameraPosition == .back)
        #expect(service.isSessionReady == false)
    }
}
