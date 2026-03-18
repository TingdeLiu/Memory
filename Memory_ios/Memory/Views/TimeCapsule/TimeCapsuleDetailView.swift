import SwiftUI
import MapKit

struct TimeCapsuleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let capsule: TimeCapsule

    @State private var showingUnlockConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var justUnlocked = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if capsule.isUnlocked {
                    unlockedHeader
                    memoryContent
                } else {
                    lockedHeader
                    unlockConditionCard
                    lockedPreview
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(String(localized: "capsule.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !capsule.isUnlocked && capsule.unlockType == .event {
                        Button {
                            showingUnlockConfirm = true
                        } label: {
                            Label(String(localized: "capsule.action.unlock"), systemImage: "lock.open")
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label(String(localized: "capsule.action.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(String(localized: "capsule.unlock.confirm.title"), isPresented: $showingUnlockConfirm) {
            Button(String(localized: "capsule.action.unlock"), role: .destructive) {
                withAnimation(.spring(response: 0.6)) {
                    TimeCapsuleService.shared.unlockManually(capsule: capsule, modelContext: modelContext)
                    justUnlocked = true
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "capsule.unlock.confirm.message"))
        }
        .alert(String(localized: "capsule.delete.confirm.title"), isPresented: $showingDeleteConfirm) {
            Button(String(localized: "capsule.action.delete"), role: .destructive) {
                modelContext.delete(capsule)
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "capsule.delete.confirm.message"))
        }
        .onAppear {
            // Auto-unlock date capsules if ready
            if !capsule.isUnlocked && capsule.isReady {
                withAnimation(.spring(response: 0.6)) {
                    capsule.unlock()
                    justUnlocked = true
                }
            }
        }
        .sensoryFeedback(.success, trigger: justUnlocked)
    }

    // MARK: - Unlocked State

    private var unlockedHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.05)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "gift.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }
            .scaleEffect(justUnlocked ? 1.2 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: justUnlocked)

            Text(String(localized: "capsule.opened.title"))
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(String(localized: "capsule.detail.created"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(capsule.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let openedAt = capsule.unlockedAt {
                    VStack(spacing: 2) {
                        Text(String(localized: "capsule.detail.opened"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(openedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private var memoryContent: some View {
        Group {
            if let memory = capsule.memory {
                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if let mood = memory.mood {
                                Text(mood.emoji)
                                    .font(.title3)
                            }
                            Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        if !memory.content.isEmpty {
                            Text(memory.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }

                        HStack(spacing: 8) {
                            Label(memory.type.rawValue, systemImage: typeIcon(for: memory.type))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Locked State

    private var lockedHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pulsing rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.orange.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .purple.opacity(0.1)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "hourglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.top, 20)

            Text(String(localized: "capsule.sealed.title"))
                .font(.title2)
                .fontWeight(.bold)

            // Countdown
            if let target = capsule.countdownTarget {
                CountdownView(targetDate: target, style: .detailed)
            } else if capsule.unlockType == .location {
                Label(String(localized: "capsule.waiting.location"), systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if capsule.unlockType == .event {
                Label(String(localized: "capsule.waiting.event"), systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }

            Text(String(localized: "capsule.detail.sealedOn \(capsule.createdAt.formatted(date: .abbreviated, time: .omitted))"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var unlockConditionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(capsule.unlockType.label, systemImage: capsule.unlockType.icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)

            Text(capsule.conditionSummary)
                .font(.body)
                .foregroundStyle(.primary)

            // Map for location capsules
            if capsule.unlockType == .location,
               let lat = capsule.unlockLatitude,
               let lng = capsule.unlockLongitude {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: (capsule.unlockRadius ?? 200) * 4,
                    longitudinalMeters: (capsule.unlockRadius ?? 200) * 4
                )
                Map(initialPosition: .region(region)) {
                    MapCircle(center: coordinate, radius: capsule.unlockRadius ?? 200)
                        .foregroundStyle(.orange.opacity(0.2))
                        .stroke(.orange, lineWidth: 2)
                    Marker("", coordinate: coordinate)
                        .tint(.orange)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var lockedPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(.secondary)

            if let memory = capsule.memory {
                Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                    .font(.headline)
                    .blur(radius: 8)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "capsule.locked.hint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func typeIcon(for type: MemoryType) -> String {
        switch type {
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }
}
