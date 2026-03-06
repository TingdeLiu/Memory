import Foundation
import SwiftData

/// Manages local SwiftData persistence and provides data export/import.
actor StorageService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Export

    /// Export all data as a structured JSON.
    func exportAllDataAsJSON() async throws -> Data {
        let context = ModelContext(modelContainer)

        let memories = try context.fetch(FetchDescriptor<MemoryEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        let contacts = try context.fetch(FetchDescriptor<Contact>(sortBy: [SortDescriptor(\.name)]))
        let messages = try context.fetch(FetchDescriptor<Message>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))

        let memoriesExport: [[String: Any]] = memories.map { m in
            var dict: [String: Any] = [
                "id": m.id.uuidString,
                "title": m.title,
                "content": m.content,
                "type": m.type.rawValue,
                "tags": m.tags,
                "isPrivate": m.isPrivate,
                "createdAt": ISO8601DateFormatter().string(from: m.createdAt),
                "updatedAt": ISO8601DateFormatter().string(from: m.updatedAt),
            ]
            if let mood = m.mood { dict["mood"] = mood.rawValue }
            if let dur = m.audioDuration { dict["audioDuration"] = dur }
            if let trans = m.transcription { dict["transcription"] = trans }
            return dict
        }

        let contactsExport: [[String: Any]] = contacts.map { c in
            [
                "id": c.id.uuidString,
                "name": c.name,
                "relationship": c.relationship.rawValue,
                "isFavorite": c.isFavorite,
                "notes": c.notes,
                "importSource": c.importSource.rawValue,
                "createdAt": ISO8601DateFormatter().string(from: c.createdAt),
                "messageCount": c.messages.count,
            ]
        }

        let messagesExport: [[String: Any]] = messages.map { m in
            var dict: [String: Any] = [
                "id": m.id.uuidString,
                "content": m.content,
                "type": m.type.rawValue,
                "deliveryCondition": m.deliveryCondition.rawValue,
                "createdAt": ISO8601DateFormatter().string(from: m.createdAt),
                "updatedAt": ISO8601DateFormatter().string(from: m.updatedAt),
            ]
            if let date = m.deliveryDate {
                dict["deliveryDate"] = ISO8601DateFormatter().string(from: date)
            }
            if let dur = m.audioDuration { dict["audioDuration"] = dur }
            if let contact = m.contact {
                dict["contactName"] = contact.name
                dict["contactId"] = contact.id.uuidString
            }
            return dict
        }

        let export: [String: Any] = [
            "appName": "Memory",
            "exportVersion": 1,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "summary": [
                "memoriesCount": memories.count,
                "contactsCount": contacts.count,
                "messagesCount": messages.count,
            ],
            "memories": memoriesExport,
            "contacts": contactsExport,
            "messages": messagesExport,
        ]

        return try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    /// Export as a human-readable plain text document.
    func exportAsPlainText() async throws -> String {
        let context = ModelContext(modelContainer)

        let memories = try context.fetch(FetchDescriptor<MemoryEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        let contacts = try context.fetch(FetchDescriptor<Contact>(sortBy: [SortDescriptor(\.name)]))

        var text = """
        ==========================================
        MEMORY — Your Personal Archive
        Exported: \(Date().formatted(date: .long, time: .shortened))
        ==========================================

        """

        // Memories
        text += "\n--- MEMORIES (\(memories.count)) ---\n\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        for memory in memories {
            text += "[\(dateFormatter.string(from: memory.createdAt))]"
            if let mood = memory.mood { text += " \(mood.emoji)" }
            text += "\n"
            if !memory.title.isEmpty { text += "\(memory.title)\n" }
            if !memory.content.isEmpty { text += "\(memory.content)\n" }
            if !memory.tags.isEmpty { text += "Tags: \(memory.tags.joined(separator: ", "))\n" }
            if let transcription = memory.transcription {
                text += "Transcription: \(transcription)\n"
            }
            text += "\n"
        }

        // Contacts & Messages
        text += "\n--- CONTACTS & MESSAGES (\(contacts.count) people) ---\n\n"
        for contact in contacts {
            text += "## \(contact.name) (\(contact.relationship.label))\n"
            if !contact.notes.isEmpty { text += "   \(contact.notes)\n" }
            let sorted = contact.sortedMessages
            if !sorted.isEmpty {
                for msg in sorted {
                    text += "   [\(dateFormatter.string(from: msg.createdAt))] "
                    text += "(\(msg.deliveryCondition.label)) "
                    text += msg.content
                    text += "\n"
                }
            }
            text += "\n"
        }

        text += "\n==========================================\n"
        text += "End of export. \(memories.count) memories, \(contacts.count) contacts.\n"

        return text
    }

    // MARK: - Statistics

    /// Get data statistics.
    func getStatistics() async throws -> DataStatistics {
        let context = ModelContext(modelContainer)

        let memories = try context.fetch(FetchDescriptor<MemoryEntry>())
        let contacts = try context.fetch(FetchDescriptor<Contact>())
        let messages = try context.fetch(FetchDescriptor<Message>())

        let textMemories = memories.filter { $0.type == .text }.count
        let audioMemories = memories.filter { $0.type == .audio }.count
        let photoMemories = memories.filter { $0.type == .photo }.count
        let privateMemories = memories.filter { $0.isPrivate }.count

        let immediateMessages = messages.filter { $0.deliveryCondition == .immediate }.count
        let scheduledMessages = messages.filter { $0.deliveryCondition == .specificDate }.count
        let sealedMessages = messages.filter { $0.deliveryCondition == .afterDeath }.count

        let oldestDate = memories.min(by: { $0.createdAt < $1.createdAt })?.createdAt

        return DataStatistics(
            totalMemories: memories.count,
            textMemories: textMemories,
            audioMemories: audioMemories,
            photoMemories: photoMemories,
            privateMemories: privateMemories,
            totalContacts: contacts.count,
            totalMessages: messages.count,
            immediateMessages: immediateMessages,
            scheduledMessages: scheduledMessages,
            sealedMessages: sealedMessages,
            oldestMemoryDate: oldestDate
        )
    }

    // MARK: - Delete All

    /// Delete all data and clean up associated files.
    func deleteAllData() async throws {
        let context = ModelContext(modelContainer)

        // Clean up audio files
        let memories = try context.fetch(FetchDescriptor<MemoryEntry>())
        for memory in memories {
            if let path = memory.audioFilePath {
                let url = AudioRecordingService.recordingURL(for: path)
                try? EncryptionHelper.secureDelete(at: url)
            }
        }

        let messages = try context.fetch(FetchDescriptor<Message>())
        for message in messages {
            if let path = message.audioFilePath {
                let url = AudioRecordingService.recordingURL(for: path)
                try? EncryptionHelper.secureDelete(at: url)
            }
        }

        try context.delete(model: MemoryEntry.self)
        try context.delete(model: Message.self)
        try context.delete(model: Contact.self)
        try context.save()
    }
}

// MARK: - Data Statistics

struct DataStatistics {
    let totalMemories: Int
    let textMemories: Int
    let audioMemories: Int
    let photoMemories: Int
    let privateMemories: Int
    let totalContacts: Int
    let totalMessages: Int
    let immediateMessages: Int
    let scheduledMessages: Int
    let sealedMessages: Int
    let oldestMemoryDate: Date?
}
