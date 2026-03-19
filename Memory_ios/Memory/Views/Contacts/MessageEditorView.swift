import SwiftUI
import SwiftData

struct MessageEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: Contact
    var existingMessage: Message?
    var prefillContent: String?

    @State private var content = ""
    @State private var deliveryCondition: DeliveryCondition = .immediate
    @State private var deliveryDate = Date()
    @State private var showingDiscardAlert = false

    // Voice recording
    @State private var recorder = AudioRecordingService()
    @State private var audioURL: URL?
    @State private var audioDuration: TimeInterval = 0
    @State private var showingRecordingSheet = false
    @State private var messageType: MessageType = .text

    // Writing style rewrite
    @Query private var writingProfiles: [WritingStyleProfile]
    @State private var isRewriting = false

    private var isEditing: Bool { existingMessage != nil }
    private var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || audioURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Recipient
                Section {
                    HStack(spacing: 12) {
                        ContactAvatarView(contact: contact, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.messageTo(contact.name))
                                .font(.headline)
                            Label(contact.relationship.label, systemImage: contact.relationship.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Message type toggle
                Section {
                    Picker(String(localized: "messageEditor.type"), selection: $messageType) {
                        Label(String(localized: "memoryType.text"), systemImage: "text.bubble").tag(MessageType.text)
                        Label(String(localized: "memoryType.voice"), systemImage: "waveform").tag(MessageType.audio)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal)
                }

                // Content based on type
                if messageType == .text {
                    Section(String(localized: "messageEditor.message")) {
                        TextEditor(text: $content)
                            .frame(minHeight: 180)
                            .overlay(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text(L10n.messagePlaceholder(contact.name))
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // Rewrite in my style
                    if let styleProfile = writingProfiles.first, styleProfile.isReady,
                       !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            Button {
                                Task { await rewriteInMyStyle(profile: styleProfile) }
                            } label: {
                                HStack {
                                    if isRewriting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(String(localized: "messageEditor.rewriteInMyStyle"))
                                    Spacer()
                                }
                            }
                            .disabled(isRewriting)
                        } footer: {
                            Text(String(localized: "messageEditor.rewriteHint"))
                        }
                    }
                } else {
                    // Voice message section
                    Section(String(localized: "messageEditor.voiceMessage")) {
                        if let url = audioURL {
                            VoiceMessagePreview(
                                url: url,
                                duration: audioDuration,
                                onReRecord: {
                                    recorder.deleteRecording(at: url)
                                    audioURL = nil
                                    audioDuration = 0
                                    showingRecordingSheet = true
                                },
                                onDelete: {
                                    recorder.deleteRecording(at: url)
                                    audioURL = nil
                                    audioDuration = 0
                                }
                            )
                        } else {
                            Button {
                                showingRecordingSheet = true
                            } label: {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "mic.circle.fill")
                                            .font(.system(size: 44))
                                            .foregroundStyle(Color.accentColor)
                                        Text(String(localized: "messageEditor.tapToRecord"))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Optional text alongside voice
                        TextField(String(localized: "messageEditor.addNote"), text: $content, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                // Delivery settings
                Section {
                    ForEach(DeliveryCondition.allCases, id: \.self) { condition in
                        Button {
                            withAnimation { deliveryCondition = condition }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: condition.icon)
                                    .font(.title3)
                                    .foregroundStyle(conditionColor(condition))
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(condition.label)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(condition.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if deliveryCondition == condition {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if deliveryCondition == .specificDate {
                        DatePicker(
                            String(localized: "messageEditor.deliveryDate"),
                            selection: $deliveryDate,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                        .transition(.opacity)
                    }
                } header: {
                    Text(String(localized: "messageEditor.whenToDeliver"))
                } footer: {
                    if deliveryCondition == .afterDeath {
                        Text(String(localized: "messageEditor.sealedFooter"))
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "messageEditor.editTitle") : String(localized: "messageEditor.newTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        if hasContent && !isEditing {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasContent)
                }
            }
            .alert(String(localized: "messageEditor.discardTitle"), isPresented: $showingDiscardAlert) {
                Button(String(localized: "memoryEditor.discardButton"), role: .destructive) {
                    if let url = audioURL {
                        recorder.deleteRecording(at: url)
                    }
                    dismiss()
                }
                Button(String(localized: "memoryEditor.keepEditing"), role: .cancel) {}
            }
            .sheet(isPresented: $showingRecordingSheet) {
                VoiceRecordingSheet(
                    recorder: recorder,
                    onSave: { url, duration in
                        audioURL = url
                        audioDuration = duration
                    }
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                if let msg = existingMessage {
                    content = msg.content
                    deliveryCondition = msg.deliveryCondition
                    messageType = msg.type
                    if let date = msg.deliveryDate {
                        deliveryDate = date
                    }
                    if let path = msg.audioFilePath {
                        audioURL = AudioRecordingService.recordingURL(for: path)
                        audioDuration = msg.audioDuration ?? 0
                    }
                } else if let prefill = prefillContent {
                    content = prefill
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        if let msg = existingMessage {
            msg.content = content
            msg.type = messageType
            msg.deliveryCondition = deliveryCondition
            msg.deliveryDate = deliveryCondition == .specificDate ? deliveryDate : nil
            if let url = audioURL {
                msg.audioFilePath = url.lastPathComponent
                msg.audioDuration = audioDuration
            } else {
                msg.audioFilePath = nil
                msg.audioDuration = nil
            }
            msg.updatedAt = Date()
        } else {
            let message = Message(
                content: content,
                type: messageType,
                deliveryCondition: deliveryCondition,
                deliveryDate: deliveryCondition == .specificDate ? deliveryDate : nil,
                audioFilePath: audioURL?.lastPathComponent,
                audioDuration: audioURL != nil ? audioDuration : nil,
                contact: contact
            )
            modelContext.insert(message)
        }
    }

    private func rewriteInMyStyle(profile: WritingStyleProfile) async {
        isRewriting = true
        defer { isRewriting = false }

        let prompt = """
        Rewrite the following message to \(contact.name) (\(contact.relationship.rawValue)) \
        in my personal writing style. Keep the meaning and intent, but make it sound like me:

        \(content)
        """

        do {
            let rewritten = try await WritingStyleService.shared.generateInStyle(
                prompt: prompt,
                profile: profile,
                aiService: AIService()
            )
            content = rewritten
        } catch {
            // Keep original content on failure
        }
    }

    private func conditionColor(_ condition: DeliveryCondition) -> Color {
        switch condition {
        case .immediate: return .green
        case .specificDate: return .orange
        case .afterDeath: return .purple
        }
    }
}

// MARK: - Voice Message Preview

struct VoiceMessagePreview: View {
    let url: URL
    let duration: TimeInterval
    let onReRecord: () -> Void
    let onDelete: () -> Void

    @State private var player = AudioPlaybackService()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    try? player.togglePlayback(url: url)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5)).frame(height: 4)
                            Capsule().fill(Color.accentColor).frame(width: geo.size.width * player.progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(formatTime(player.isPlaying ? player.currentTime : 0))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                Button(action: onReRecord) {
                    Label(String(localized: "memoryEditor.reRecord"), systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label(String(localized: "common.remove"), systemImage: "trash")
                        .font(.caption)
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MessageEditorView(contact: Contact(name: "Mom", relationship: .family))
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
