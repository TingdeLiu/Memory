import SwiftUI
import SwiftData

struct MessageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let message: Message

    @State private var player = AudioPlaybackService()
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipient header
                    if let contact = message.contact {
                        HStack(spacing: 12) {
                            ContactAvatarView(contact: contact, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.messageTo(contact.name))
                                    .font(.headline)
                                Label(contact.relationship.label, systemImage: contact.relationship.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Status badge
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: message.deliveryCondition.icon)
                            Text(message.statusLabel)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.1))
                        .clipShape(Capsule())
                        .accessibilityLabel(String(localized: "messageDetail.deliveryStatus") + " " + message.statusLabel)

                        Text(message.createdAt.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Delivery date info
                    if message.deliveryCondition == .specificDate, let date = message.deliveryDate {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.orange)
                            if Date() >= date {
                                Text(String(localized: "messageDetail.deliveredOn") + " " + date.formatted(date: .long, time: .omitted))
                            } else {
                                Text(String(localized: "messageDetail.scheduledFor") + " " + date.formatted(date: .long, time: .omitted))
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    if message.deliveryCondition == .afterDeath {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.purple)
                            Text(String(localized: "messageDetail.sealedInfo"))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(Color.purple.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Divider()

                    // Audio player
                    if message.type == .audio, let path = message.audioFilePath {
                        audioSection(path: path)
                    }

                    // Text content
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.body)
                            .lineSpacing(6)
                    }

                    // Metadata
                    if message.updatedAt.timeIntervalSince(message.createdAt) > 1 {
                        Text(String(localized: "messageDetail.edited") + " " + message.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "messageDetail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label(String(localized: "common.edit"), systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(String(localized: "messageDetail.deleteTitle"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    if let path = message.audioFilePath {
                        AudioRecordingService().deleteRecording(
                            at: AudioRecordingService.recordingURL(for: path)
                        )
                    }
                    modelContext.delete(message)
                    dismiss()
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "messageDetail.deleteMessage"))
            }
            .sheet(isPresented: $showingEditSheet) {
                if let contact = message.contact {
                    MessageEditorView(contact: contact, existingMessage: message)
                }
            }
            .onDisappear {
                player.stop()
            }
        }
    }

    // MARK: - Audio Section

    private func audioSection(path: String) -> some View {
        let url = AudioRecordingService.recordingURL(for: path)
        return HStack(spacing: 16) {
            Button {
                try? player.togglePlayback(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.accent)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * player.progress, height: 6)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                player.seek(to: max(0, min(1, value.location.x / geo.size.width)))
                            }
                    )
                }
                .frame(height: 6)

                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(message.audioDuration ?? player.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        switch message.deliveryCondition {
        case .immediate: return .green
        case .specificDate:
            if let date = message.deliveryDate, Date() >= date { return .green }
            return .orange
        case .afterDeath: return .purple
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MessageDetailView(message: Message(
        content: "Mom, I just want you to know that you are the most important person in my world. Everything I am today is because of you.",
        deliveryCondition: .afterDeath
    ))
    .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
