import Foundation
import SwiftData
import SwiftUI

// MARK: - Memory Insight

struct MemoryInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let icon: String
    let color: Color
    let relatedMemoryIDs: [UUID]
    let actionLabel: String?

    enum InsightType: String {
        case onThisDay
        case moodTrend
        case milestone
        case reflectionPrompt
        case connectionSuggestion
    }
}

// MARK: - Memory Insight Service

@Observable
final class MemoryInsightService {
    static let shared = MemoryInsightService()

    var insights: [MemoryInsight] = []
    var dailyPrompt: String?

    private init() {}

    // MARK: - Generate All Insights

    func generateInsights(
        memories: [MemoryEntry],
        soulProfile: SoulProfile?,
        contacts: [Contact]
    ) {
        var results: [MemoryInsight] = []

        results.append(contentsOf: findOnThisDayMemories(memories))
        results.append(contentsOf: detectMoodTrends(memories))
        results.append(contentsOf: checkMilestones(memories))
        results.append(contentsOf: suggestConnections(memories, contacts: contacts))

        if let prompt = generateReflectionPrompt(soulProfile: soulProfile, memories: memories) {
            results.append(prompt)
        }

        insights = results
    }

    // MARK: - On This Day

    private func findOnThisDayMemories(_ memories: [MemoryEntry]) -> [MemoryInsight] {
        let calendar = Calendar.current
        let today = Date()
        let todayComponents = calendar.dateComponents([.month, .day], from: today)

        let matches = memories.filter { entry in
            let entryComponents = calendar.dateComponents([.month, .day, .year], from: entry.createdAt)
            let todayYear = calendar.component(.year, from: today)
            return entryComponents.month == todayComponents.month
                && entryComponents.day == todayComponents.day
                && entryComponents.year != todayYear
        }

        guard !matches.isEmpty else { return [] }

        let yearsAgo = matches.map { entry -> Int in
            let years = calendar.dateComponents([.year], from: entry.createdAt, to: today).year ?? 0
            return years
        }

        let title: String
        if let minYears = yearsAgo.min(), minYears == 1 {
            title = String(localized: "insight.onThisDay.lastYear")
        } else if let minYears = yearsAgo.min() {
            title = String(localized: "insight.onThisDay.yearsAgo \(minYears)")
        } else {
            title = String(localized: "insight.onThisDay.title")
        }

        let preview = matches.first.map { $0.title } ?? ""
        let message = matches.count == 1
            ? String(localized: "insight.onThisDay.single \(preview)")
            : String(localized: "insight.onThisDay.multiple \(matches.count)")

        return [MemoryInsight(
            type: .onThisDay,
            title: title,
            message: message,
            icon: "clock.arrow.circlepath",
            color: .blue,
            relatedMemoryIDs: matches.map(\.id),
            actionLabel: String(localized: "insight.action.view")
        )]
    }

    // MARK: - Mood Trends

    private func detectMoodTrends(_ memories: [MemoryEntry]) -> [MemoryInsight] {
        let calendar = Calendar.current
        let recentDays = 7
        guard let cutoff = calendar.date(byAdding: .day, value: -recentDays, to: Date()) else { return [] }

        let recentMemories = memories
            .filter { $0.createdAt >= cutoff && $0.mood != nil }
            .sorted { $0.createdAt > $1.createdAt }

        guard recentMemories.count >= 3 else { return [] }

        // Count moods in recent period
        let moodCounts = Dictionary(grouping: recentMemories, by: { $0.mood! })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }

        guard let dominant = moodCounts.first, dominant.value >= 3 else { return [] }

        let moodEmoji = dominant.key.emoji
        let moodLabel = dominant.key.label
        let ratio = Double(dominant.value) / Double(recentMemories.count)

        // Negative mood alert
        let negativeMoods: Set<String> = ["sad", "angry", "anxious", "stressed"]
        let isNegative = negativeMoods.contains(dominant.key.rawValue)

        if isNegative && ratio >= 0.5 {
            return [MemoryInsight(
                type: .moodTrend,
                title: String(localized: "insight.mood.alert.title"),
                message: String(localized: "insight.mood.alert.message \(moodEmoji) \(moodLabel) \(dominant.value)"),
                icon: "heart.text.clipboard",
                color: .orange,
                relatedMemoryIDs: recentMemories.prefix(5).map(\.id),
                actionLabel: String(localized: "insight.action.talkToAI")
            )]
        }

        // Positive streak
        let positiveMoods: Set<String> = ["happy", "grateful", "excited", "peaceful"]
        let isPositive = positiveMoods.contains(dominant.key.rawValue)

        if isPositive && ratio >= 0.6 {
            return [MemoryInsight(
                type: .moodTrend,
                title: String(localized: "insight.mood.positive.title"),
                message: String(localized: "insight.mood.positive.message \(moodEmoji) \(dominant.value)"),
                icon: "sun.max.fill",
                color: .yellow,
                relatedMemoryIDs: [],
                actionLabel: nil
            )]
        }

        return []
    }

    // MARK: - Milestones

    private func checkMilestones(_ memories: [MemoryEntry]) -> [MemoryInsight] {
        let count = memories.count
        let milestones = [10, 25, 50, 100, 200, 365, 500, 1000]

        for milestone in milestones {
            if count == milestone {
                return [MemoryInsight(
                    type: .milestone,
                    title: String(localized: "insight.milestone.title \(milestone)"),
                    message: String(localized: "insight.milestone.message \(milestone)"),
                    icon: "trophy.fill",
                    color: .yellow,
                    relatedMemoryIDs: [],
                    actionLabel: nil
                )]
            }
        }

        // First memory anniversary
        if let first = memories.last {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month, .day], from: first.createdAt)
            let todayComponents = calendar.dateComponents([.month, .day, .year], from: Date())
            let firstYear = calendar.component(.year, from: first.createdAt)

            if components.month == todayComponents.month
                && components.day == todayComponents.day
                && firstYear != todayComponents.year {
                let years = (todayComponents.year ?? 0) - firstYear
                return [MemoryInsight(
                    type: .milestone,
                    title: String(localized: "insight.anniversary.title"),
                    message: String(localized: "insight.anniversary.message \(years)"),
                    icon: "birthday.cake.fill",
                    color: .pink,
                    relatedMemoryIDs: [first.id],
                    actionLabel: String(localized: "insight.action.view")
                )]
            }
        }

        return []
    }

    // MARK: - Connection Suggestions

    private func suggestConnections(_ memories: [MemoryEntry], contacts: [Contact]) -> [MemoryInsight] {
        let calendar = Calendar.current
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else { return [] }

        // Find contacts with no recent messages
        let neglectedContacts = contacts.filter { contact in
            let hasRecentMessage = contact.messages.contains { $0.createdAt > thirtyDaysAgo }
            let isFavorite = contact.isFavorite
            return !hasRecentMessage && isFavorite
        }

        guard let contact = neglectedContacts.first else { return [] }

        let daysSince = contact.messages
            .sorted { $0.createdAt > $1.createdAt }
            .first
            .map { calendar.dateComponents([.day], from: $0.createdAt, to: Date()).day ?? 0 } ?? 0

        if daysSince > 14 {
            return [MemoryInsight(
                type: .connectionSuggestion,
                title: String(localized: "insight.connection.title"),
                message: String(localized: "insight.connection.message \(contact.name) \(daysSince)"),
                icon: "person.wave.2.fill",
                color: .purple,
                relatedMemoryIDs: [],
                actionLabel: String(localized: "insight.action.writeMessage")
            )]
        }

        return []
    }

    // MARK: - Reflection Prompt

    private func generateReflectionPrompt(soulProfile: SoulProfile?, memories: [MemoryEntry]) -> MemoryInsight? {
        // Generate a daily reflection question personalized to the user
        let prompts: [String]

        if let profile = soulProfile, let mbti = profile.mbtiType {
            // Personalized prompts based on MBTI
            let mbtiType = MBTIType(rawValue: mbti)
            if mbtiType?.isIntrovert == true {
                prompts = [
                    String(localized: "insight.prompt.introvert.1"),
                    String(localized: "insight.prompt.introvert.2"),
                    String(localized: "insight.prompt.introvert.3"),
                    String(localized: "insight.prompt.introvert.4"),
                    String(localized: "insight.prompt.introvert.5"),
                ]
            } else {
                prompts = [
                    String(localized: "insight.prompt.extrovert.1"),
                    String(localized: "insight.prompt.extrovert.2"),
                    String(localized: "insight.prompt.extrovert.3"),
                    String(localized: "insight.prompt.extrovert.4"),
                    String(localized: "insight.prompt.extrovert.5"),
                ]
            }
        } else {
            prompts = [
                String(localized: "insight.prompt.general.1"),
                String(localized: "insight.prompt.general.2"),
                String(localized: "insight.prompt.general.3"),
                String(localized: "insight.prompt.general.4"),
                String(localized: "insight.prompt.general.5"),
            ]
        }

        // Use day of year as seed for consistent daily prompt
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % prompts.count
        let prompt = prompts[index]

        dailyPrompt = prompt

        return MemoryInsight(
            type: .reflectionPrompt,
            title: String(localized: "insight.reflection.title"),
            message: prompt,
            icon: "lightbulb.fill",
            color: .mint,
            relatedMemoryIDs: [],
            actionLabel: String(localized: "insight.action.record")
        )
    }
}
