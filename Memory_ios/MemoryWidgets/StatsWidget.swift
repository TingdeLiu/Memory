import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), stats: WidgetStats(
            totalMemories: 42, thisWeekCount: 5,
            topMoodEmoji: "😊", topMoodLabel: "Happy",
            totalContacts: 8, totalMessages: 15,
            sealedCapsules: 2, streakDays: 7
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let stats = WidgetDataReader.readStats()
        completion(StatsEntry(date: Date(), stats: stats))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let stats = WidgetDataReader.readStats()
        let entry = StatsEntry(date: Date(), stats: stats)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetStats
}

// MARK: - Widget Views

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StatsEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.accentColor)
                Spacer()
                if entry.stats.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(entry.stats.streakDays)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
            }

            VStack(spacing: 4) {
                Text("\(entry.stats.totalMemories)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(String(localized: "widget.stat.memories"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(entry.stats.thisWeekCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text(String(localized: "widget.stat.week"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let emoji = entry.stats.topMoodEmoji {
                    VStack(spacing: 2) {
                        Text(emoji)
                            .font(.caption)
                        Text(String(localized: "widget.stat.mood"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: total count
            VStack(spacing: 4) {
                Text("\(entry.stats.totalMemories)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(String(localized: "widget.stat.memories"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Right: details
            VStack(alignment: .leading, spacing: 8) {
                StatRow(icon: "calendar", label: String(localized: "widget.stat.week"), value: "\(entry.stats.thisWeekCount)")
                if let emoji = entry.stats.topMoodEmoji {
                    StatRow(icon: "heart", label: String(localized: "widget.stat.mood"), value: emoji)
                }
                if entry.stats.streakDays > 0 {
                    StatRow(icon: "flame.fill", label: String(localized: "widget.stat.streak"), value: "\(entry.stats.streakDays)d")
                }
                if entry.stats.sealedCapsules > 0 {
                    StatRow(icon: "hourglass", label: String(localized: "widget.stat.capsules"), value: "\(entry.stats.sealedCapsules)")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Lock Screen

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.stats.totalMemories)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(entry.stats.topMoodEmoji ?? "")
                    .font(.caption2)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                Text("\(entry.stats.totalMemories) " + String(localized: "widget.stat.memories"))
                    .font(.headline)
            }
            HStack(spacing: 8) {
                Label("\(entry.stats.thisWeekCount)", systemImage: "calendar")
                if entry.stats.streakDays > 0 {
                    Label("\(entry.stats.streakDays)d", systemImage: "flame.fill")
                }
                if let emoji = entry.stats.topMoodEmoji {
                    Text(emoji)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var inlineView: some View {
        Label(
            "\(entry.stats.totalMemories) memories \(entry.stats.topMoodEmoji ?? "")",
            systemImage: "brain.head.profile"
        )
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Widget Configuration

struct StatsWidget: Widget {
    let kind = "StatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.stats.title"))
        .description(String(localized: "widget.stats.description"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

#Preview("Stats Small", as: .systemSmall) {
    StatsWidget()
} timeline: {
    StatsEntry(date: .now, stats: WidgetStats(
        totalMemories: 42, thisWeekCount: 5,
        topMoodEmoji: "😊", topMoodLabel: "Happy",
        totalContacts: 8, totalMessages: 15,
        sealedCapsules: 2, streakDays: 7
    ))
}
