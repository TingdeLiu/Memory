import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]
    @State private var showingEditor = false
    @State private var searchText = ""
    @State private var showingDateFilter = false
    @State private var dateFilterStart: Date?
    @State private var dateFilterEnd: Date?
    @State private var showingAIChat = false
    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"

    private var isFullEncryption: Bool {
        EncryptionLevel(rawValue: encryptionLevelRaw) == .full
    }

    private var filteredMemories: [MemoryEntry] {
        var result = memories.filter { !$0.title.hasPrefix("[Draft] ") }
        if !searchText.isEmpty {
            // In full encryption mode, search uses decrypted computed properties (in-memory filtering)
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if let start = dateFilterStart {
            result = result.filter { $0.createdAt >= start }
        }
        if let end = dateFilterEnd {
            result = result.filter { $0.createdAt <= Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end }
        }
        return result
    }

    private var groupedMemories: [(String, [MemoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMemories) { entry -> String in
            if calendar.isDateInToday(entry.createdAt) {
                return String(localized: "home.date.today")
            } else if calendar.isDateInYesterday(entry.createdAt) {
                return String(localized: "home.date.yesterday")
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                      entry.createdAt > weekAgo {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: entry.createdAt)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                return formatter.string(from: entry.createdAt)
            }
        }
        return grouped.sorted { $0.value[0].createdAt > $1.value[0].createdAt }
    }

    // Stats
    private var totalMemories: Int { memories.filter { !$0.title.hasPrefix("[Draft] ") }.count }
    private var thisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return memories.filter { !$0.title.hasPrefix("[Draft] ") && $0.createdAt > weekAgo }.count
    }
    private var hasDateFilter: Bool { dateFilterStart != nil || dateFilterEnd != nil }

    var body: some View {
        NavigationStack {
            Group {
                if memories.filter({ !$0.title.hasPrefix("[Draft] ") }).isEmpty {
                    emptyState
                } else {
                    timelineContent
                }
            }
            .navigationTitle(String(localized: "home.title"))
            .searchable(text: $searchText, prompt: String(localized: "home.search.prompt"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if totalMemories > 0 {
                        Menu {
                            Button {
                                showingDateFilter = true
                            } label: {
                                Label(String(localized: "home.filter.date"), systemImage: "calendar")
                            }
                            if hasDateFilter {
                                Button {
                                    dateFilterStart = nil
                                    dateFilterEnd = nil
                                } label: {
                                    Label(String(localized: "home.filter.clear"), systemImage: "xmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: hasDateFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                MemoryEditorView()
            }
            .sheet(isPresented: $showingAIChat) {
                AIChatView()
            }
            .sheet(isPresented: $showingDateFilter) {
                DateFilterSheet(
                    startDate: $dateFilterStart,
                    endDate: $dateFilterEnd
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 72))
                .foregroundStyle(.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text(String(localized: "home.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "home.empty.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    showingEditor = true
                } label: {
                    Label(String(localized: "home.empty.button"), systemImage: "pencil.line")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .sensoryFeedback(.impact(weight: .light), trigger: showingEditor)

                Text(String(localized: "home.empty.hint"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        List {
            // Quick stats
            if searchText.isEmpty && !hasDateFilter {
                statsBar
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                // AI quick access
                if StoreService.shared.isPremium && aiEnabled && AIService().hasAPIKey(for: AIService().selectedProvider) {
                    aiQuickAccess
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            // Date filter indicator
            if hasDateFilter {
                HStack {
                    Image(systemName: "calendar")
                    if let start = dateFilterStart, let end = dateFilterEnd {
                        Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
                    } else if let start = dateFilterStart {
                        Text(L10n.homeFilterFrom(start.formatted(date: .abbreviated, time: .omitted)))
                    } else if let end = dateFilterEnd {
                        Text(L10n.homeFilterUntil(end.formatted(date: .abbreviated, time: .omitted)))
                    }
                    Spacer()
                    Button {
                        dateFilterStart = nil
                        dateFilterEnd = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.accentColor.opacity(0.05))
            }

            // Timeline
            if filteredMemories.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(groupedMemories, id: \.0) { dateString, entries in
                    Section {
                        ForEach(entries) { entry in
                            NavigationLink(destination: MemoryDetailView(memory: entry)) {
                                MemoryTimelineRow(memory: entry)
                            }
                        }
                    } header: {
                        HStack {
                            Text(dateString)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(entries.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - AI Quick Access

    private var aiQuickAccess: some View {
        Button {
            showingAIChat = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.ai.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(String(localized: "home.ai.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityLabel(String(localized: "home.ai.title"))
        .accessibilityHint(String(localized: "home.ai.subtitle"))
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(title: String(localized: "home.stat.total"), value: "\(totalMemories)", icon: "brain", color: .accent)
                StatCard(title: String(localized: "home.stat.thisWeek"), value: "\(thisWeekCount)", icon: "calendar", color: .green)

                let moods = Dictionary(grouping: memories.compactMap(\.mood), by: { $0 })
                if let topMood = moods.max(by: { $0.value.count < $1.value.count })?.key {
                    StatCard(title: String(localized: "home.stat.topMood"), value: topMood.emoji, icon: "heart", color: .pink)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Timeline Row (enhanced)

struct MemoryTimelineRow: View {
    let memory: MemoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type indicator
            Circle()
                .fill(typeColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: typeIcon)
                        .font(.subheadline)
                        .foregroundStyle(typeColor)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if let mood = memory.mood {
                        Text(mood.emoji)
                            .font(.subheadline)
                    }
                    Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if memory.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !memory.content.isEmpty {
                    Text(memory.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Thumbnail for photos
                if let data = memory.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Video thumbnail
                if memory.type == .video, let data = memory.videoThumbnailData, let uiImage = UIImage(data: data) {
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 2)
                    }
                }

                // Audio duration
                if memory.type == .audio, let dur = memory.audioDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                        Text(formatDuration(dur))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }

                // Video duration
                if memory.type == .video, let dur = memory.videoDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "video")
                        Text(formatDuration(dur))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    if !memory.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(memory.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }
                            if memory.tags.count > 2 {
                                Text("+\(memory.tags.count - 2)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Spacer()
                    Text(memory.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timelineAccessibilityLabel)
    }

    private var timelineAccessibilityLabel: String {
        var parts: [String] = []
        switch memory.type {
        case .audio: parts.append(String(localized: "timeline.type.voice"))
        case .photo: parts.append(String(localized: "timeline.type.photo"))
        case .video: parts.append(String(localized: "timeline.type.video"))
        case .text: parts.append(String(localized: "timeline.type.text"))
        }
        parts.append(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
        if let mood = memory.mood { parts.append(mood.label) }
        if !memory.tags.isEmpty { parts.append(L10n.tagsCount(memory.tags.count)) }
        if memory.isPrivate { parts.append(String(localized: "timeline.private")) }
        return parts.joined(separator: ", ")
    }

    private var typeIcon: String {
        switch memory.type {
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    private var typeColor: Color {
        switch memory.type {
        case .text: return .accent
        case .audio: return .orange
        case .photo: return .green
        case .video: return .purple
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Date Filter Sheet

struct DateFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    @State private var tempStart = Date()
    @State private var tempEnd = Date()
    @State private var useStartDate = false
    @State private var useEndDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "dateFilter.fromDate"), isOn: $useStartDate)
                    if useStartDate {
                        DatePicker(String(localized: "dateFilter.start"), selection: $tempStart, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle(String(localized: "dateFilter.toDate"), isOn: $useEndDate)
                    if useEndDate {
                        DatePicker(String(localized: "dateFilter.end"), selection: $tempEnd, displayedComponents: .date)
                    }
                }

                Section {
                    Button(String(localized: "dateFilter.clearAll")) {
                        startDate = nil
                        endDate = nil
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle(String(localized: "dateFilter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "dateFilter.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "dateFilter.apply")) {
                        startDate = useStartDate ? tempStart : nil
                        endDate = useEndDate ? tempEnd : nil
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let s = startDate { tempStart = s; useStartDate = true }
                if let e = endDate { tempEnd = e; useEndDate = true }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
