import Testing
import Foundation
@testable import Memory

// MARK: - Widget Data Tests

@Suite("Widget Data Tests")
struct WidgetDataTests {

    // MARK: - AppGroupConfig

    @Test func appGroupConfigKeysNotEmpty() {
        #expect(!AppGroupConfig.suiteName.isEmpty)
        #expect(!AppGroupConfig.recentMemoriesKey.isEmpty)
        #expect(!AppGroupConfig.statsKey.isEmpty)
        #expect(!AppGroupConfig.capsuleKey.isEmpty)
        #expect(!AppGroupConfig.lastUpdateKey.isEmpty)
    }

    @Test func appGroupSuiteName() {
        #expect(AppGroupConfig.suiteName == "group.com.tyndall.memory")
    }

    // MARK: - WidgetMemory Codable

    @Test func widgetMemoryCodableRoundtrip() throws {
        let memory = WidgetMemory(
            id: UUID(),
            title: "Test Memory",
            contentPreview: "This is a preview...",
            type: "text",
            moodEmoji: "😊",
            moodLabel: "Happy",
            tags: ["test", "coding"],
            isPrivate: false,
            isLocked: false,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(WidgetMemory.self, from: data)

        #expect(decoded.id == memory.id)
        #expect(decoded.title == "Test Memory")
        #expect(decoded.contentPreview == "This is a preview...")
        #expect(decoded.type == "text")
        #expect(decoded.moodEmoji == "😊")
        #expect(decoded.moodLabel == "Happy")
        #expect(decoded.tags == ["test", "coding"])
        #expect(decoded.isPrivate == false)
        #expect(decoded.isLocked == false)
    }

    @Test func widgetMemoryWithNilMood() throws {
        let memory = WidgetMemory(
            id: UUID(),
            title: "No Mood",
            contentPreview: "",
            type: "audio",
            moodEmoji: nil,
            moodLabel: nil,
            tags: [],
            isPrivate: true,
            isLocked: true,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(WidgetMemory.self, from: data)

        #expect(decoded.moodEmoji == nil)
        #expect(decoded.moodLabel == nil)
        #expect(decoded.isPrivate == true)
        #expect(decoded.isLocked == true)
    }

    @Test func widgetMemoryArrayRoundtrip() throws {
        let memories = [
            WidgetMemory(id: UUID(), title: "First", contentPreview: "", type: "text", moodEmoji: nil, moodLabel: nil, tags: [], isPrivate: false, isLocked: false, createdAt: Date()),
            WidgetMemory(id: UUID(), title: "Second", contentPreview: "", type: "photo", moodEmoji: "📷", moodLabel: nil, tags: ["photo"], isPrivate: false, isLocked: false, createdAt: Date()),
        ]

        let data = try JSONEncoder().encode(memories)
        let decoded = try JSONDecoder().decode([WidgetMemory].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].title == "First")
        #expect(decoded[1].title == "Second")
    }

    // MARK: - WidgetStats Codable

    @Test func widgetStatsCodableRoundtrip() throws {
        let stats = WidgetStats(
            totalMemories: 42,
            thisWeekCount: 7,
            topMoodEmoji: "😊",
            topMoodLabel: "Happy",
            totalContacts: 15,
            totalMessages: 8,
            sealedCapsules: 3,
            streakDays: 12
        )

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(WidgetStats.self, from: data)

        #expect(decoded.totalMemories == 42)
        #expect(decoded.thisWeekCount == 7)
        #expect(decoded.topMoodEmoji == "😊")
        #expect(decoded.totalContacts == 15)
        #expect(decoded.totalMessages == 8)
        #expect(decoded.sealedCapsules == 3)
        #expect(decoded.streakDays == 12)
    }

    @Test func widgetStatsWithNilMood() throws {
        let stats = WidgetStats(
            totalMemories: 0,
            thisWeekCount: 0,
            topMoodEmoji: nil,
            topMoodLabel: nil,
            totalContacts: 0,
            totalMessages: 0,
            sealedCapsules: 0,
            streakDays: 0
        )

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(WidgetStats.self, from: data)

        #expect(decoded.totalMemories == 0)
        #expect(decoded.topMoodEmoji == nil)
    }

    // MARK: - WidgetCapsule Codable

    @Test func widgetCapsuleCodableRoundtrip() throws {
        let capsule = WidgetCapsule(
            id: UUID(),
            unlockType: "date",
            unlockDate: Date().addingTimeInterval(86400),
            locationName: nil,
            eventDescription: nil,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(capsule)
        let decoded = try JSONDecoder().decode(WidgetCapsule.self, from: data)

        #expect(decoded.id == capsule.id)
        #expect(decoded.unlockType == "date")
        #expect(decoded.unlockDate != nil)
        #expect(decoded.locationName == nil)
    }

    @Test func widgetCapsuleLocationType() throws {
        let capsule = WidgetCapsule(
            id: UUID(),
            unlockType: "location",
            unlockDate: nil,
            locationName: "Central Park",
            eventDescription: nil,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(capsule)
        let decoded = try JSONDecoder().decode(WidgetCapsule.self, from: data)

        #expect(decoded.unlockType == "location")
        #expect(decoded.locationName == "Central Park")
    }

    @Test func widgetCapsuleEventType() throws {
        let capsule = WidgetCapsule(
            id: UUID(),
            unlockType: "event",
            unlockDate: nil,
            locationName: nil,
            eventDescription: "When I graduate",
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(capsule)
        let decoded = try JSONDecoder().decode(WidgetCapsule.self, from: data)

        #expect(decoded.unlockType == "event")
        #expect(decoded.eventDescription == "When I graduate")
    }

    @Test func widgetCapsuleArrayRoundtrip() throws {
        let capsules = [
            WidgetCapsule(id: UUID(), unlockType: "date", unlockDate: Date(), locationName: nil, eventDescription: nil, createdAt: Date()),
            WidgetCapsule(id: UUID(), unlockType: "event", unlockDate: nil, locationName: nil, eventDescription: "Party", createdAt: Date()),
        ]

        let data = try JSONEncoder().encode(capsules)
        let decoded = try JSONDecoder().decode([WidgetCapsule].self, from: data)

        #expect(decoded.count == 2)
    }

    // MARK: - WidgetDataReader Defaults

    @Test func readerReturnsEmptyMemoriesWhenNoData() {
        let memories = WidgetDataReader.readRecentMemories()
        #expect(memories.isEmpty)
    }

    @Test func readerReturnsDefaultStatsWhenNoData() {
        let stats = WidgetDataReader.readStats()
        #expect(stats.totalMemories == 0)
        #expect(stats.thisWeekCount == 0)
        #expect(stats.topMoodEmoji == nil)
        #expect(stats.streakDays == 0)
    }

    @Test func readerReturnsEmptyCapsulesWhenNoData() {
        let capsules = WidgetDataReader.readCapsules()
        #expect(capsules.isEmpty)
    }
}
