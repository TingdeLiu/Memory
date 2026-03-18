import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct RecentMemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentMemoryEntry {
        RecentMemoryEntry(
            date: Date(),
            memory: WidgetMemory(
                id: UUID(),
                title: String(localized: "widget.placeholder.title"),
                contentPreview: String(localized: "widget.placeholder.content"),
                type: "text",
                moodEmoji: "😊",
                moodLabel: nil,
                tags: [],
                isPrivate: false,
                isLocked: false,
                createdAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentMemoryEntry) -> Void) {
        let memories = WidgetDataReader.readRecentMemories()
        let entry = RecentMemoryEntry(
            date: Date(),
            memory: memories.first ?? placeholder(in: context).memory
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentMemoryEntry>) -> Void) {
        let memories = WidgetDataReader.readRecentMemories()
        let calendar = Calendar.current

        var entries: [RecentMemoryEntry] = []

        if memories.isEmpty {
            entries.append(RecentMemoryEntry(date: Date(), memory: nil))
        } else {
            // Rotate through recent memories every 2 hours
            for (index, memory) in memories.prefix(5).enumerated() {
                let entryDate = calendar.date(byAdding: .hour, value: index * 2, to: Date()) ?? Date()
                entries.append(RecentMemoryEntry(date: entryDate, memory: memory))
            }
        }

        let nextUpdate = calendar.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct RecentMemoryEntry: TimelineEntry {
    let date: Date
    let memory: WidgetMemory?
}

// MARK: - Widget Views

struct RecentMemoryWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RecentMemoryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
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

    // MARK: - Small (2x2 Home Screen)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let memory = entry.memory {
                if memory.isLocked {
                    lockedSmallView
                } else {
                    HStack {
                        if let emoji = memory.moodEmoji {
                            Text(emoji)
                                .font(.title2)
                        }
                        Spacer()
                        Image(systemName: typeIcon(for: memory.type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(memory.title)
                        .font(.headline)
                        .lineLimit(2)

                    if !memory.contentPreview.isEmpty {
                        Text(memory.contentPreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Text(memory.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                emptyView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var lockedSmallView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.title)
                .foregroundStyle(.orange)
            Text(String(localized: "capsule.sealed"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Medium (4x2 Home Screen)

    private var mediumView: some View {
        HStack(spacing: 12) {
            if let memory = entry.memory, !memory.isLocked {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let emoji = memory.moodEmoji {
                            Text(emoji)
                                .font(.title3)
                        }
                        Text(memory.title)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    if !memory.contentPreview.isEmpty {
                        Text(memory.contentPreview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Label(memory.type, systemImage: typeIcon(for: memory.type))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Text(memory.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !memory.tags.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(memory.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .frame(width: 60)
                }
            } else {
                emptyView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Large (4x4 Home Screen)

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.accentColor)
                Text("Memory")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            if let memory = entry.memory, !memory.isLocked {
                // Main card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if let emoji = memory.moodEmoji {
                            Text(emoji)
                                .font(.title2)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memory.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(memory.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: typeIcon(for: memory.type))
                            .foregroundStyle(.secondary)
                    }

                    if !memory.contentPreview.isEmpty {
                        Text(memory.contentPreview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }

                    if !memory.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(memory.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 8)

                // Stats row
                let stats = WidgetDataReader.readStats()
                HStack(spacing: 16) {
                    WidgetStatItem(value: "\(stats.totalMemories)", label: String(localized: "widget.stat.total"), icon: "brain")
                    WidgetStatItem(value: "\(stats.thisWeekCount)", label: String(localized: "widget.stat.week"), icon: "calendar")
                    if let emoji = stats.topMoodEmoji {
                        WidgetStatItem(value: emoji, label: String(localized: "widget.stat.mood"), icon: "heart")
                    }
                    if stats.streakDays > 0 {
                        WidgetStatItem(value: "\(stats.streakDays)", label: String(localized: "widget.stat.streak"), icon: "flame")
                    }
                }
            } else {
                Spacer()
                emptyView
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Lock Screen Widgets

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let memory = entry.memory, let emoji = memory.moodEmoji {
                Text(emoji)
                    .font(.title)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let memory = entry.memory {
                HStack(spacing: 4) {
                    if let emoji = memory.moodEmoji {
                        Text(emoji)
                    }
                    Text(memory.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(memory.contentPreview.isEmpty ? memory.createdAt.formatted(date: .abbreviated, time: .omitted) : memory.contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label("Memory", systemImage: "brain.head.profile")
                    .font(.headline)
                Text(String(localized: "widget.empty.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        if let memory = entry.memory {
            Label(
                "\(memory.moodEmoji ?? "") \(memory.title)",
                systemImage: typeIcon(for: memory.type)
            )
        } else {
            Label("Memory", systemImage: "brain.head.profile")
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(String(localized: "widget.empty.title"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func typeIcon(for type: String) -> String {
        switch type {
        case "text": return "doc.text"
        case "audio": return "waveform"
        case "photo": return "photo"
        case "video": return "video"
        default: return "doc"
        }
    }
}

// MARK: - Stat Item

private struct WidgetStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Configuration

struct RecentMemoryWidget: Widget {
    let kind = "RecentMemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentMemoryProvider()) { entry in
            RecentMemoryWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.recent.title"))
        .description(String(localized: "widget.recent.description"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RecentMemoryWidget()
} timeline: {
    RecentMemoryEntry(date: .now, memory: WidgetMemory(
        id: UUID(), title: "A beautiful day", contentPreview: "Walked through the park and watched the sunset...",
        type: "text", moodEmoji: "😊", moodLabel: "Happy", tags: ["nature", "peace"],
        isPrivate: false, isLocked: false, createdAt: Date()
    ))
    RecentMemoryEntry(date: .now, memory: nil)
}

#Preview("Medium", as: .systemMedium) {
    RecentMemoryWidget()
} timeline: {
    RecentMemoryEntry(date: .now, memory: WidgetMemory(
        id: UUID(), title: "A beautiful day", contentPreview: "Walked through the park and watched the sunset glow across the lake.",
        type: "text", moodEmoji: "😌", moodLabel: "Calm", tags: ["nature", "peace", "sunset"],
        isPrivate: false, isLocked: false, createdAt: Date()
    ))
}
