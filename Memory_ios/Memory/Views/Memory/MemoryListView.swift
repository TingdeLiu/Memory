import SwiftUI
import SwiftData

struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]
    @State private var viewModel: MemoryListViewModel?
    @State private var showingReel = false

    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"
    private var isFullEncryption: Bool { EncryptionLevel(rawValue: encryptionLevelRaw) == .full }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let vm = viewModel {
                    VStack(spacing: 0) {
                        filterBar

                        ScrollView {
                            LazyVStack(spacing: 20) {
                                let filtered = vm.filterAndSort(memories)

                                if filtered.isEmpty {
                                    ContentUnavailableView(
                                        vm.searchText.isEmpty ? String(localized: "memoryList.empty") : String(localized: "memoryList.noResults"),
                                        systemImage: vm.searchText.isEmpty ? "doc.on.doc" : "magnifyingglass"
                                    )
                                    .padding(.top, 60)
                                } else {
                                    ForEach(filtered) { memory in
                                        NavigationLink(destination: MemoryDetailView(memory: memory)) {
                                            MemoryCardView(memory: memory)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                vm.deleteMemories([memory])
                                            } label: {
                                                Label(String(localized: "common.delete"), systemImage: "trash")
                                            }
                                        }
                                    }
                                }

                                Color.clear.frame(height: 20)
                            }
                            .padding(.top, 16)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "memoryList.title"))
            .searchable(text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ), prompt: String(localized: "memoryList.search"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !(viewModel?.filterAndSort(memories).isEmpty ?? true) {
                        Button {
                            showingReel = true
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.title3)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(String(localized: "memoryList.sort"), selection: Binding(
                            get: { viewModel?.sortOrder ?? .reverse },
                            set: { viewModel?.sortOrder = $0 }
                        )) {
                            ForEach(MemoryListViewModel.SortOrder.allCases, id: \.self) { order in
                                if order == .alphabetical && isFullEncryption {
                                    // Hide alphabetical sort in full encryption mode if needed
                                } else {
                                    Text(order.label).tag(order)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel?.showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingEditor ?? false },
                set: { viewModel?.showingEditor = $0 }
            )) {
                MemoryEditorView()
            }
            .fullScreenCover(isPresented: $showingReel) {
                MemoryReelView(memories: viewModel?.filterAndSort(memories) ?? [])
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = MemoryListViewModel(modelContext: modelContext)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Type Filter
                Menu {
                    Button(String(localized: "filter.allTypes")) { viewModel?.selectedType = nil }
                    ForEach(MemoryType.allCases, id: \.self) { type in
                        Button(type.rawValue.capitalized) { viewModel?.selectedType = type }
                    }
                } label: {
                    FilterBadge(
                        label: viewModel?.selectedType?.rawValue.capitalized ?? String(localized: "filter.type"),
                        isActive: viewModel?.selectedType != nil,
                        icon: "line.3.horizontal.decrease"
                    )
                }

                // Mood Filter
                Menu {
                    Button(String(localized: "filter.allMoods")) { viewModel?.selectedMood = nil }
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button("\(mood.emoji) \(mood.label)") { viewModel?.selectedMood = mood }
                    }
                } label: {
                    FilterBadge(
                        label: viewModel?.selectedMood?.label ?? String(localized: "filter.mood"),
                        isActive: viewModel?.selectedMood != nil,
                        icon: "face.smiling"
                    )
                }

                if viewModel?.selectedType != nil || viewModel?.selectedMood != nil {
                    Button {
                        viewModel?.selectedType = nil
                        viewModel?.selectedMood = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.background)
    }
}

struct FilterBadge: View {
    let label: String
    let isActive: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
    }
}
