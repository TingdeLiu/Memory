import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct CapsuleProvider: TimelineProvider {
    func placeholder(in context: Context) -> CapsuleEntry {
        CapsuleEntry(date: Date(), capsules: [
            WidgetCapsule(
                id: UUID(), unlockType: "date",
                unlockDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                locationName: nil, eventDescription: nil, createdAt: Date()
            )
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (CapsuleEntry) -> Void) {
        let capsules = WidgetDataReader.readCapsules()
        completion(CapsuleEntry(date: Date(), capsules: capsules))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CapsuleEntry>) -> Void) {
        let capsules = WidgetDataReader.readCapsules()
        let entry = CapsuleEntry(date: Date(), capsules: capsules)

        // Refresh every hour for countdown accuracy
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct CapsuleEntry: TimelineEntry {
    let date: Date
    let capsules: [WidgetCapsule]
}

// MARK: - Widget Views

struct CapsuleWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CapsuleEntry

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
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 8) {
            if let capsule = entry.capsules.first {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                if let unlockDate = capsule.unlockDate, unlockDate > Date() {
                    Text(unlockDate, style: .relative)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    conditionLabel(for: capsule)
                }

                Text(String(localized: "widget.capsule.sealed"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if entry.capsules.count > 1 {
                    Text(String(localized: "widget.capsule.more \(entry.capsules.count - 1)"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Countdown
            VStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                if let capsule = entry.capsules.first, let unlockDate = capsule.unlockDate, unlockDate > Date() {
                    Text(unlockDate, style: .relative)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            // List
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.capsules.prefix(3)) { capsule in
                    HStack(spacing: 6) {
                        Image(systemName: unlockIcon(for: capsule.unlockType))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .frame(width: 14)

                        conditionLabel(for: capsule)
                            .lineLimit(1)

                        Spacer()
                    }
                }

                if entry.capsules.isEmpty {
                    Text(String(localized: "widget.capsule.none"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Image(systemName: "hourglass")
                    .font(.caption)
                Text("\(entry.capsules.count)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                Text(String(localized: "widget.capsule.title"))
                    .font(.headline)
            }

            if let capsule = entry.capsules.first {
                if let unlockDate = capsule.unlockDate, unlockDate > Date() {
                    Text(unlockDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    conditionLabel(for: capsule)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "widget.capsule.none"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(String(localized: "widget.capsule.none"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func conditionLabel(for capsule: WidgetCapsule) -> some View {
        switch capsule.unlockType {
        case "date":
            if let date = capsule.unlockDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        case "location":
            Text(capsule.locationName ?? String(localized: "capsule.condition.location"))
                .font(.caption)
                .foregroundStyle(.blue)
        case "event":
            Text(capsule.eventDescription ?? String(localized: "capsule.condition.event"))
                .font(.caption)
                .foregroundStyle(.purple)
        default:
            EmptyView()
        }
    }

    private func unlockIcon(for type: String) -> String {
        switch type {
        case "date": return "calendar.badge.clock"
        case "location": return "mappin.and.ellipse"
        case "event": return "sparkles"
        default: return "hourglass"
        }
    }
}

// MARK: - Widget Configuration

struct CapsuleCountdownWidget: Widget {
    let kind = "CapsuleCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CapsuleProvider()) { entry in
            CapsuleWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.capsule.config.title"))
        .description(String(localized: "widget.capsule.config.description"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

#Preview("Capsule Small", as: .systemSmall) {
    CapsuleCountdownWidget()
} timeline: {
    CapsuleEntry(date: .now, capsules: [
        WidgetCapsule(
            id: UUID(), unlockType: "date",
            unlockDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            locationName: nil, eventDescription: nil, createdAt: Date()
        )
    ])
}
