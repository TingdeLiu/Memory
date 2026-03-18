import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]
    @Query(filter: #Predicate<TimeCapsule> { !$0.isUnlocked }, sort: \TimeCapsule.createdAt, order: .reverse) private var lockedCapsules: [TimeCapsule]
    @State private var viewModel: HomeViewModel?

    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"

    private var publishedMemories: [MemoryEntry] {
        memories.filter { !$0.title.hasPrefix("[Draft] ") }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if publishedMemories.isEmpty {
                    emptyState
                } else {
                    timelineContent
                }
            }
            .navigationTitle(String(localized: "home.title"))
            .searchable(text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ), prompt: String(localized: "home.search.prompt"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel?.showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !memories.isEmpty {
                        Menu {
                            Button {
                                viewModel?.showingDateFilter = true
                            } label: {
                                Label(String(localized: "home.filter.date"), systemImage: "calendar")
                            }
                            if viewModel?.hasDateFilter == true {
                                Button {
                                    viewModel?.clearDateFilter()
                                } label: {
                                    Label(String(localized: "home.filter.clear"), systemImage: "xmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: viewModel?.hasDateFilter == true ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingEditor ?? false },
                set: { viewModel?.showingEditor = $0 }
            )) {
                MemoryEditorView()
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingAIChat ?? false },
                set: { viewModel?.showingAIChat = $0 }
            )) {
                AIChatView()
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingDateFilter ?? false },
                set: { viewModel?.showingDateFilter = $0 }
            )) {
                DateFilterSheet(
                    startDate: Binding(
                        get: { viewModel?.dateFilterStart },
                        set: { viewModel?.dateFilterStart = $0 }
                    ),
                    endDate: Binding(
                        get: { viewModel?.dateFilterEnd },
                        set: { viewModel?.dateFilterEnd = $0 }
                    )
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = HomeViewModel(modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor.opacity(0.6))

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
                    viewModel?.showingEditor = true
                } label: {
                    Label(String(localized: "home.empty.button"), systemImage: "pencil.line")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

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
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                // Quick stats & AI (Non-pinned)
                if viewModel?.searchText.isEmpty == true && viewModel?.hasDateFilter != true {
                    VStack(spacing: 16) {
                        statsBar

                        if !lockedCapsules.isEmpty {
                            timeCapsuleCard
                        }

                        if StoreService.shared.isPremium && aiEnabled && AIService().hasAPIKey(for: AIService().selectedProvider) {
                            aiQuickAccess
                        }
                    }
                    .padding(.top, 12)
                }

                // Date filter indicator
                if viewModel?.hasDateFilter == true {
                    dateFilterIndicator
                }

                // Timeline Sections
                let filtered = viewModel?.filterMemories(memories) ?? []
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: viewModel?.searchText ?? "")
                        .padding(.top, 40)
                } else {
                    let grouped = viewModel?.groupMemories(filtered) ?? []
                    ForEach(grouped, id: \.0) { dateString, entries in
                        Section {
                            ForEach(entries) { entry in
                                NavigationLink(destination: MemoryDetailView(memory: entry)) {
                                    MemoryCardView(memory: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } header: {
                            sectionHeader(title: dateString, count: entries.count)
                        }
                    }
                }
                
                // Bottom padding
                Color.clear.frame(height: 20)
            }
        }
    }
    
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            
            Spacer()
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 24)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground).opacity(0.8))
    }

    private var dateFilterIndicator: some View {
        HStack {
            Image(systemName: "calendar")
            if let start = viewModel?.dateFilterStart, let end = viewModel?.dateFilterEnd {
                Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
            } else if let start = viewModel?.dateFilterStart {
                Text("From \(start.formatted(date: .abbreviated, time: .omitted))")
            } else if let end = viewModel?.dateFilterEnd {
                Text("Until \(end.formatted(date: .abbreviated, time: .omitted))")
            }
            Spacer()
            Button {
                viewModel?.clearDateFilter()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private var timeCapsuleCard: some View {
        NavigationLink(destination: TimeCapsuleListView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "hourglass")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.capsule.title"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if let next = lockedCapsules
                        .filter({ $0.countdownTarget != nil })
                        .sorted(by: { ($0.countdownTarget ?? .distantFuture) < ($1.countdownTarget ?? .distantFuture) })
                        .first {
                        CountdownView(targetDate: next.countdownTarget, style: .compact)
                    } else {
                        Text(String(localized: "home.capsule.count \(lockedCapsules.count)"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(lockedCapsules.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var aiQuickAccess: some View {
        Button {
            viewModel?.showingAIChat = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.ai.title"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(String(localized: "home.ai.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var statsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(title: String(localized: "home.stat.total"), value: "\(memories.count)", icon: "brain", color: Color.accentColor)
                
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let thisWeek = memories.filter { $0.createdAt > weekAgo }.count
                StatCard(title: String(localized: "home.stat.thisWeek"), value: "\(thisWeek)", icon: "calendar", color: .green)

                let moods = Dictionary(grouping: memories.compactMap(\.mood), by: { $0 })
                if let topMood = moods.max(by: { $0.value.count < $1.value.count })?.key {
                    StatCard(title: String(localized: "home.stat.topMood"), value: topMood.emoji, icon: "heart", color: .pink)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Date Filter Sheet

struct DateFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    @State private var tempStart: Date = Date()
    @State private var tempEnd: Date = Date()
    @State private var hasStart = false
    @State private var hasEnd = false

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "dateFilter.fromDate")) {
                    Toggle(String(localized: "dateFilter.start"), isOn: $hasStart)
                    if hasStart {
                        DatePicker("", selection: $tempStart, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }

                Section(String(localized: "dateFilter.toDate")) {
                    Toggle(String(localized: "dateFilter.end"), isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("", selection: $tempEnd, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }

                if startDate != nil || endDate != nil {
                    Button(String(localized: "dateFilter.clearAll"), role: .destructive) {
                        startDate = nil
                        endDate = nil
                        dismiss()
                    }
                }
            }
            .navigationTitle(String(localized: "dateFilter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        startDate = hasStart ? tempStart : nil
                        endDate = hasEnd ? tempEnd : nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let start = startDate {
                    tempStart = start
                    hasStart = true
                }
                if let end = endDate {
                    tempEnd = end
                    hasEnd = true
                }
            }
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
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 100)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
