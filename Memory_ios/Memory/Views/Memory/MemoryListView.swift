import SwiftUI
import SwiftData

struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]
    @State private var searchText = ""
    @State private var selectedMood: Mood?
    @State private var selectedTag: String?
    @State private var selectedType: MemoryType?
    @State private var showingEditor = false
    @State private var sortOrder: SortOrder = .newest
    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"

    private var isFullEncryption: Bool {
        EncryptionLevel(rawValue: encryptionLevelRaw) == .full
    }

    enum SortOrder: String, CaseIterable {
        case newest, oldest, title

        var label: String {
            switch self {
            case .newest: return String(localized: "memoryList.sort.newest")
            case .oldest: return String(localized: "memoryList.sort.oldest")
            case .title: return String(localized: "memoryList.sort.title")
            }
        }
    }

    private var nonDraftMemories: [MemoryEntry] {
        memories.filter { !$0.title.hasPrefix("[Draft] ") }
    }

    private var filteredMemories: [MemoryEntry] {
        var result = nonDraftMemories
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                ($0.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        if let mood = selectedMood {
            result = result.filter { $0.mood == mood }
        }
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        switch sortOrder {
        case .newest: result.sort { $0.createdAt > $1.createdAt }
        case .oldest: result.sort { $0.createdAt < $1.createdAt }
        case .title:
            // In full encryption mode, title is encrypted so sorting is approximate
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }

        return result
    }

    private var allTags: [String] {
        Array(Set(nonDraftMemories.flatMap(\.tags))).sorted()
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedMood != nil { count += 1 }
        if selectedTag != nil { count += 1 }
        if selectedType != nil { count += 1 }
        return count
    }

    var body: some View {
        NavigationStack {
            Group {
                if nonDraftMemories.isEmpty {
                    ContentUnavailableView(
                        String(localized: "memoryList.empty.title"),
                        systemImage: "brain.head.profile",
                        description: Text(String(localized: "memoryList.empty.subtitle"))
                    )
                } else {
                    List {
                        filterSection

                        // Results header
                        if activeFilterCount > 0 || !searchText.isEmpty {
                            HStack {
                                Text(L10n.memoryListResults(filteredMemories.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if activeFilterCount > 0 {
                                    Button {
                                        selectedMood = nil
                                        selectedTag = nil
                                        selectedType = nil
                                    } label: {
                                        Text(String(localized: "memoryList.clearFilters"))
                                            .font(.caption)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }

                        if filteredMemories.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            ForEach(filteredMemories) { memory in
                                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                                    MemoryTimelineRow(memory: memory)
                                }
                            }
                            .onDelete(perform: deleteMemories)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(String(localized: "memoryList.title"))
            .searchable(text: $searchText, prompt: String(localized: "memoryList.search.prompt"))
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
                    Menu {
                        Picker(String(localized: "memoryList.sort"), selection: $sortOrder) {
                            ForEach(SortOrder.allCases.filter { order in
                                // In full encryption mode, title sort is less reliable
                                !(isFullEncryption && order == .title)
                            }, id: \.self) { order in
                                Text(order.label).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                MemoryEditorView()
            }
        }
    }

    // MARK: - Filter Section

    @ViewBuilder
    private var filterSection: some View {
        Section {
            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        label: String(localized: "common.all"),
                        isSelected: selectedType == nil
                    ) {
                        selectedType = nil
                    }

                    ForEach(MemoryType.allCases, id: \.self) { type in
                        FilterChip(
                            label: typeLabel(type),
                            isSelected: selectedType == type
                        ) {
                            selectedType = selectedType == type ? nil : type
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Mood filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        FilterChip(
                            label: "\(mood.emoji) \(mood.label)",
                            isSelected: selectedMood == mood
                        ) {
                            selectedMood = selectedMood == mood ? nil : mood
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Tag filter
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            FilterChip(
                                label: tag,
                                isSelected: selectedTag == tag
                            ) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - Helpers

    private func typeLabel(_ type: MemoryType) -> String {
        switch type {
        case .text: return String(localized: "memoryType.text")
        case .audio: return String(localized: "memoryType.voice")
        case .photo: return String(localized: "memoryType.photo")
        case .video: return String(localized: "memoryType.video")
        }
    }

    private func deleteMemories(at offsets: IndexSet) {
        for index in offsets {
            let memory = filteredMemories[index]
            if let path = memory.audioFilePath {
                let url = AudioRecordingService.recordingURL(for: path)
                AudioRecordingService().deleteRecording(at: url)
            }
            if let path = memory.videoFilePath {
                let url = AudioRecordingService.recordingURL(for: path)
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(memory)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                .foregroundStyle(isSelected ? .accent : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? String(localized: "common.a11y.deselect") : String(localized: "common.a11y.filter"))
    }
}

#Preview {
    MemoryListView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
