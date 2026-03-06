import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: Contact

    @State private var showingMessageEditor = false
    @State private var showingContactEditor = false
    @State private var showingDeleteAlert = false
    @State private var selectedConditionFilter: DeliveryCondition?
    @State private var selectedMessage: Message?

    private var filteredMessages: [Message] {
        if let condition = selectedConditionFilter {
            return contact.messages(for: condition)
        }
        return contact.sortedMessages
    }

    private var messageCountByCondition: [DeliveryCondition: Int] {
        Dictionary(grouping: contact.messages, by: \.deliveryCondition)
            .mapValues(\.count)
    }

    var body: some View {
        List {
            // Profile header
            profileSection

            // Quick actions
            actionSection

            // Notes
            if !contact.notes.isEmpty {
                Section(String(localized: "contactDetail.about")) {
                    Text(contact.notes)
                        .font(.body)
                }
            }

            // Message stats
            if !contact.messages.isEmpty {
                messageStatsSection
            }

            // Message filter & list
            messagesSection
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingContactEditor = true
                    } label: {
                        Label(String(localized: "contactDetail.editContact"), systemImage: "pencil")
                    }

                    Button {
                        contact.isFavorite.toggle()
                    } label: {
                        Label(
                            contact.isFavorite ? String(localized: "contactDetail.removeFavorite") : String(localized: "contactDetail.addFavorite"),
                            systemImage: contact.isFavorite ? "star.slash" : "star.fill"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(String(localized: "contactDetail.deleteContact"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingMessageEditor) {
            MessageEditorView(contact: contact)
        }
        .sheet(isPresented: $showingContactEditor) {
            ContactEditorView(existingContact: contact)
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailView(message: message)
        }
        .alert(String(localized: "contactDetail.deleteTitle"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "common.delete"), role: .destructive) {
                for msg in contact.messages {
                    if let path = msg.audioFilePath {
                        AudioRecordingService().deleteRecording(
                            at: AudioRecordingService.recordingURL(for: path)
                        )
                    }
                }
                modelContext.delete(contact)
                dismiss()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.contactDeleteMessage(contact.name, contact.messages.count))
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            VStack(spacing: 14) {
                ContactAvatarView(contact: contact, size: 88)

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(contact.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        if contact.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.subheadline)
                        }
                    }

                    Label(contact.relationship.label, systemImage: contact.relationship.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if contact.importSource == .systemContacts {
                    Label(String(localized: "contactDetail.imported"), systemImage: "person.crop.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Section {
            HStack(spacing: 12) {
                ActionButton(
                    title: String(localized: "contactDetail.action.write"),
                    icon: "pencil.line",
                    color: .accent
                ) {
                    showingMessageEditor = true
                }

                ActionButton(
                    title: String(localized: "contactDetail.action.edit"),
                    icon: "person.text.rectangle",
                    color: .blue
                ) {
                    showingContactEditor = true
                }

                ActionButton(
                    title: contact.isFavorite ? String(localized: "contactDetail.action.unfave") : String(localized: "contactDetail.action.fave"),
                    icon: contact.isFavorite ? "star.slash" : "star.fill",
                    color: .yellow
                ) {
                    withAnimation { contact.isFavorite.toggle() }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal)
        }
    }

    // MARK: - Message Stats

    private var messageStatsSection: some View {
        Section {
            HStack(spacing: 16) {
                ForEach(DeliveryCondition.allCases, id: \.self) { condition in
                    let count = messageCountByCondition[condition] ?? 0
                    if count > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: condition.icon)
                                .font(.title3)
                            Text("\(count)")
                                .font(.headline)
                            Text(condition.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        Section {
            // Filter
            if contact.messages.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: String(localized: "common.all") + " (\(contact.messages.count))",
                            isSelected: selectedConditionFilter == nil
                        ) {
                            selectedConditionFilter = nil
                        }

                        ForEach(DeliveryCondition.allCases, id: \.self) { condition in
                            let count = messageCountByCondition[condition] ?? 0
                            if count > 0 {
                                FilterChip(
                                    label: "\(condition.label) (\(count))",
                                    isSelected: selectedConditionFilter == condition
                                ) {
                                    selectedConditionFilter = selectedConditionFilter == condition ? nil : condition
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Message list
            if filteredMessages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "envelope")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "contactDetail.noMessages"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showingMessageEditor = true
                    } label: {
                        Label(String(localized: "contactDetail.writeFirst"), systemImage: "pencil.line")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(filteredMessages) { message in
                    Button {
                        selectedMessage = message
                    } label: {
                        MessageRowView(message: message)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let message = filteredMessages[index]
                        if let path = message.audioFilePath {
                            AudioRecordingService().deleteRecording(
                                at: AudioRecordingService.recordingURL(for: path)
                            )
                        }
                        modelContext.delete(message)
                    }
                }
            }
        } header: {
            HStack {
                Text(String(localized: "contactDetail.messages"))
                Spacer()
                if !contact.messages.isEmpty {
                    Button {
                        showingMessageEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Row View (enhanced)

struct MessageRowView: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status bar
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: message.deliveryCondition.icon)
                    Text(message.statusLabel)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
                .accessibilityLabel(String(localized: "contactDetail.statusA11y") + " " + message.statusLabel)

                if message.type == .audio {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                        if let dur = message.audioDuration {
                            Text(formatDuration(dur))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                Text(message.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Content
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.body)
                    .lineLimit(4)
            }

            // Delivery date
            if message.deliveryCondition == .specificDate, let date = message.deliveryDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                    if Date() >= date {
                        Text(String(localized: "contactDetail.delivered") + " " + date.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        Text(String(localized: "contactDetail.scheduled") + " " + date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(contact: Contact(name: "Mom", relationship: .family, notes: "The most important person in my life."))
    }
    .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
