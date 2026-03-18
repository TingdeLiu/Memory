import SwiftUI
import SwiftData

struct TimeCapsuleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeCapsule.createdAt, order: .reverse) private var capsules: [TimeCapsule]
    @State private var showingEditor = false
    @State private var selectedFilter: CapsuleFilter = .all

    enum CapsuleFilter: String, CaseIterable {
        case all, locked, unlocked

        var label: String {
            switch self {
            case .all: return String(localized: "capsule.filter.all")
            case .locked: return String(localized: "capsule.filter.locked")
            case .unlocked: return String(localized: "capsule.filter.unlocked")
            }
        }
    }

    private var filteredCapsules: [TimeCapsule] {
        switch selectedFilter {
        case .all: return capsules
        case .locked: return capsules.filter { !$0.isUnlocked }
        case .unlocked: return capsules.filter { $0.isUnlocked }
        }
    }

    private var lockedCapsules: [TimeCapsule] {
        filteredCapsules.filter { !$0.isUnlocked }
            .sorted { ($0.countdownTarget ?? .distantFuture) < ($1.countdownTarget ?? .distantFuture) }
    }

    private var unlockedCapsules: [TimeCapsule] {
        filteredCapsules.filter { $0.isUnlocked }
            .sorted { ($0.unlockedAt ?? $0.createdAt) > ($1.unlockedAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if capsules.isEmpty {
                    emptyState
                } else {
                    capsuleList
                }
            }
            .navigationTitle(String(localized: "capsule.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                TimeCapsuleEditorView()
            }
            .onAppear {
                TimeCapsuleService.shared.checkDateUnlocks(modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .opacity(0.7)

            VStack(spacing: 8) {
                Text(String(localized: "capsule.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "capsule.empty.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showingEditor = true
            } label: {
                Label(String(localized: "capsule.empty.button"), systemImage: "hourglass.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private var capsuleList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CapsuleFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation { selectedFilter = filter }
                            } label: {
                                Text(filter.label)
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.orange.opacity(0.15) : Color(.systemGray6))
                                    .foregroundStyle(selectedFilter == filter ? .orange : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)

                // Locked section
                if !lockedCapsules.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(String(localized: "capsule.section.sealed"), systemImage: "lock.fill")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(lockedCapsules) { capsule in
                            NavigationLink(destination: TimeCapsuleDetailView(capsule: capsule)) {
                                CapsuleCardView(capsule: capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Unlocked section
                if !unlockedCapsules.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(String(localized: "capsule.section.opened"), systemImage: "lock.open.fill")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(unlockedCapsules) { capsule in
                            NavigationLink(destination: TimeCapsuleDetailView(capsule: capsule)) {
                                CapsuleCardView(capsule: capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Color.clear.frame(height: 20)
            }
        }
    }
}

// MARK: - Capsule Card

struct CapsuleCardView: View {
    let capsule: TimeCapsule

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(capsule.isUnlocked
                        ? Color.green.opacity(0.12)
                        : Color.orange.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: capsule.isUnlocked ? "gift.fill" : capsule.unlockType.icon)
                    .font(.title3)
                    .foregroundStyle(capsule.isUnlocked ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Memory title (blurred if locked)
                if let memory = capsule.memory {
                    Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                        .font(.headline)
                        .lineLimit(1)
                        .blur(radius: capsule.isUnlocked ? 0 : 6)
                }

                // Condition
                HStack(spacing: 6) {
                    Image(systemName: capsule.unlockType.icon)
                        .font(.caption2)
                    Text(capsule.conditionSummary)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Countdown or open date
                if capsule.isUnlocked {
                    if let openedAt = capsule.unlockedAt {
                        Text(String(localized: "capsule.openedOn \(openedAt.formatted(date: .abbreviated, time: .omitted))"))
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                } else {
                    CountdownView(targetDate: capsule.countdownTarget, style: .compact)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
