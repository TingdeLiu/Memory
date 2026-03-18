import Foundation
import SwiftData
import WidgetKit

/// Syncs memory data to the App Group shared container for widget display.
enum WidgetDataManager {

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.suiteName)
    }

    // MARK: - Write (called from main app)

    /// Refresh all widget data from the current SwiftData context.
    static func refreshAll(modelContext: ModelContext) {
        writeRecentMemories(modelContext: modelContext)
        writeStats(modelContext: modelContext)
        writeCapsules(modelContext: modelContext)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: AppGroupConfig.lastUpdateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Write the 10 most recent memories for widget display.
    static func writeRecentMemories(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<MemoryEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        guard let memories = try? modelContext.fetch(descriptor) else { return }

        // Only include non-locked, non-private memories when encryption is full
        let isFullEncryption = EncryptionLevel.current == .full
        let widgetMemories: [WidgetMemory] = memories.compactMap { memory in
            // Skip private memories in widgets
            guard !memory.isPrivate else { return nil }

            // In full encryption mode, only show basic info
            let title: String
            let content: String
            if isFullEncryption {
                title = memory.type == .text ? String(localized: "widget.encrypted") : memory.type.rawValue
                content = ""
            } else {
                title = memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title
                content = String(memory.content.prefix(120))
            }

            return WidgetMemory(
                id: memory.id,
                title: title,
                contentPreview: content,
                type: memory.type.rawValue,
                moodEmoji: memory.mood?.emoji,
                moodLabel: memory.mood?.label,
                tags: Array(memory.tags.prefix(3)),
                isPrivate: memory.isPrivate,
                isLocked: memory.isLocked,
                createdAt: memory.createdAt
            )
        }

        if let data = try? JSONEncoder().encode(widgetMemories) {
            sharedDefaults?.set(data, forKey: AppGroupConfig.recentMemoriesKey)
        }
    }

    /// Write stats for the stats widget.
    static func writeStats(modelContext: ModelContext) {
        let allMemories = (try? modelContext.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        let contacts = (try? modelContext.fetchCount(FetchDescriptor<Contact>())) ?? 0
        let messages = (try? modelContext.fetchCount(FetchDescriptor<Message>())) ?? 0

        // This week count
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeek = allMemories.filter { $0.createdAt >= startOfWeek }.count

        // Top mood
        let moodCounts = allMemories.compactMap(\.mood).reduce(into: [:]) { counts, mood in
            counts[mood, default: 0] += 1
        }
        let topMood = moodCounts.max(by: { $0.value < $1.value })?.key

        // Sealed capsules
        let capsuleDescriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate<TimeCapsule> { !$0.isUnlocked }
        )
        let sealedCapsules = (try? modelContext.fetchCount(capsuleDescriptor)) ?? 0

        // Streak calculation
        let streakDays = calculateStreak(memories: allMemories)

        let stats = WidgetStats(
            totalMemories: allMemories.count,
            thisWeekCount: thisWeek,
            topMoodEmoji: topMood?.emoji,
            topMoodLabel: topMood?.label,
            totalContacts: contacts,
            totalMessages: messages,
            sealedCapsules: sealedCapsules,
            streakDays: streakDays
        )

        if let data = try? JSONEncoder().encode(stats) {
            sharedDefaults?.set(data, forKey: AppGroupConfig.statsKey)
        }
    }

    /// Write capsule data for countdown widget.
    static func writeCapsules(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate<TimeCapsule> { !$0.isUnlocked },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let capsules = try? modelContext.fetch(descriptor) else { return }

        let widgetCapsules: [WidgetCapsule] = capsules.prefix(5).map { capsule in
            WidgetCapsule(
                id: capsule.id,
                unlockType: capsule.unlockType.rawValue,
                unlockDate: capsule.unlockDate,
                locationName: capsule.unlockLocationName,
                eventDescription: capsule.eventDescription,
                createdAt: capsule.createdAt
            )
        }

        if let data = try? JSONEncoder().encode(widgetCapsules) {
            sharedDefaults?.set(data, forKey: AppGroupConfig.capsuleKey)
        }
    }

    // MARK: - Read (delegated to shared WidgetDataReader)

    static func readRecentMemories() -> [WidgetMemory] {
        WidgetDataReader.readRecentMemories()
    }

    static func readStats() -> WidgetStats {
        WidgetDataReader.readStats()
    }

    static func readCapsules() -> [WidgetCapsule] {
        WidgetDataReader.readCapsules()
    }

    // MARK: - Helpers

    private static func calculateStreak(memories: [MemoryEntry]) -> Int {
        let calendar = Calendar.current
        let dates = Set(memories.map { calendar.startOfDay(for: $0.createdAt) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        while dates.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
