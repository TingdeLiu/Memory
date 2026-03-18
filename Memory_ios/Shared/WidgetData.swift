import Foundation

/// Shared App Group suite name for widget data exchange.
enum AppGroupConfig {
    static let suiteName = "group.com.tyndall.memory"
    static let recentMemoriesKey = "widget_recentMemories"
    static let statsKey = "widget_stats"
    static let capsuleKey = "widget_capsules"
    static let lastUpdateKey = "widget_lastUpdate"
}

/// Lightweight, Codable memory summary for widget display.
struct WidgetMemory: Codable, Identifiable {
    let id: UUID
    let title: String
    let contentPreview: String
    let type: String // MemoryType rawValue
    let moodEmoji: String?
    let moodLabel: String?
    let tags: [String]
    let isPrivate: Bool
    let isLocked: Bool
    let createdAt: Date
}

/// Stats summary for stats widget.
struct WidgetStats: Codable {
    let totalMemories: Int
    let thisWeekCount: Int
    let topMoodEmoji: String?
    let topMoodLabel: String?
    let totalContacts: Int
    let totalMessages: Int
    let sealedCapsules: Int
    let streakDays: Int
}

/// Capsule summary for countdown widget.
struct WidgetCapsule: Codable, Identifiable {
    let id: UUID
    let unlockType: String // CapsuleUnlockType rawValue
    let unlockDate: Date?
    let locationName: String?
    let eventDescription: String?
    let createdAt: Date
}

// MARK: - Shared Data Reader (used by widget extension)

enum WidgetDataReader {
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.suiteName)
    }

    static func readRecentMemories() -> [WidgetMemory] {
        guard let data = sharedDefaults?.data(forKey: AppGroupConfig.recentMemoriesKey),
              let memories = try? JSONDecoder().decode([WidgetMemory].self, from: data)
        else { return [] }
        return memories
    }

    static func readStats() -> WidgetStats {
        guard let data = sharedDefaults?.data(forKey: AppGroupConfig.statsKey),
              let stats = try? JSONDecoder().decode(WidgetStats.self, from: data)
        else {
            return WidgetStats(
                totalMemories: 0, thisWeekCount: 0,
                topMoodEmoji: nil, topMoodLabel: nil,
                totalContacts: 0, totalMessages: 0,
                sealedCapsules: 0, streakDays: 0
            )
        }
        return stats
    }

    static func readCapsules() -> [WidgetCapsule] {
        guard let data = sharedDefaults?.data(forKey: AppGroupConfig.capsuleKey),
              let capsules = try? JSONDecoder().decode([WidgetCapsule].self, from: data)
        else { return [] }
        return capsules
    }
}
