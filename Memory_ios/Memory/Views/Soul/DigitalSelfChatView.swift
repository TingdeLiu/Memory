import SwiftUI
import SwiftData
import AVFoundation

struct DigitalSelfChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: Contact

    @Query private var configs: [DigitalSelfConfig]
    @Query private var soulProfiles: [SoulProfile]
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var writingProfiles: [WritingStyleProfile]
    @Query private var avatarProfiles: [AvatarProfile]

    @State private var messages: [DigitalSelfMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var playingMessageId: UUID?

    private let service = DigitalSelfService.shared
    private var aiService: AIService { AIService() }
    private let voiceCloneService = VoiceCloneService.shared

    private var config: DigitalSelfConfig? {
        configs.first
    }

    private var soulProfile: SoulProfile? {
        soulProfiles.first
    }

    private var voiceProfile: VoiceProfile? {
        voiceProfiles.first
    }

    private var writingProfile: WritingStyleProfile? {
        writingProfiles.first
    }

    private var avatarProfile: AvatarProfile? {
        avatarProfiles.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                DigitalSelfMessageBubble(
                                    message: message,
                                    soulProfile: soulProfile,
                                    avatarProfile: avatarProfile,
                                    contactName: contact.name,
                                    isPlaying: playingMessageId == message.id,
                                    onPlayAudio: { playAudio(for: message) }
                                )
                                .id(message.id)
                            }

                            if isGenerating {
                                TypingIndicator(soulProfile: soulProfile, avatarProfile: avatarProfile)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input Area
                inputArea
            }
            .navigationTitle(soulProfile?.displayName ?? String(localized: "digitalself.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.done")) {
                        saveConversation()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if config?.voiceOutputEnabled == true && voiceProfile?.status == .ready {
                            Button {
                                // Toggle voice output
                            } label: {
                                Label(String(localized: "digitalself.voice_output"), systemImage: "waveform")
                            }
                        }

                        Button(role: .destructive) {
                            messages.removeAll()
                        } label: {
                            Label(String(localized: "digitalself.clear_chat"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(String(localized: "common.error"), isPresented: $showingError) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                generateGreeting()
            }
            .onReceive(NotificationCenter.default.publisher(for: .digitalSelfAudioFinished)) { _ in
                playingMessageId = nil
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField(String(localized: "digitalself.input_placeholder"), text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(inputText.isEmpty ? .secondary : .purple)
            }
            .disabled(inputText.isEmpty || isGenerating)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func generateGreeting() {
        guard let soulProfile = soulProfile,
              let config = config,
              config.autoGreetEnabled else {
            return
        }

        Task {
            do {
                let greeting = try await service.generateGreeting(
                    soulProfile: soulProfile,
                    writingProfile: writingProfile,
                    config: config,
                    contactName: contact.name,
                    aiService: aiService
                )

                await MainActor.run {
                    let message = DigitalSelfMessage(role: .digitalSelf, content: greeting)
                    messages.append(message)

                    // Generate voice if enabled
                    if config.voiceOutputEnabled, let voiceProfile = voiceProfile, voiceProfile.status == .ready {
                        generateVoice(for: message)
                    }
                }
            } catch {
                // Silently fail for greeting - not critical
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = DigitalSelfMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        generateResponse()
    }

    private func generateResponse() {
        guard let soulProfile = soulProfile,
              let config = config else {
            errorMessage = String(localized: "digitalself.error.profile_incomplete")
            showingError = true
            return
        }

        isGenerating = true

        Task {
            do {
                let response = try await service.generateResponse(
                    message: messages.last?.content ?? "",
                    conversation: messages,
                    soulProfile: soulProfile,
                    writingProfile: writingProfile,
                    config: config,
                    contactName: contact.name,
                    aiService: aiService
                )

                await MainActor.run {
                    let responseMessage = DigitalSelfMessage(role: .digitalSelf, content: response)
                    messages.append(responseMessage)
                    isGenerating = false

                    // Generate voice if enabled
                    if config.voiceOutputEnabled, let voiceProfile = voiceProfile, voiceProfile.status == .ready {
                        generateVoice(for: responseMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func generateVoice(for message: DigitalSelfMessage) {
        guard let voiceProfile = voiceProfile else { return }

        Task {
            do {
                let audioURL = try await service.generateVoiceOutput(
                    text: message.content,
                    voiceProfile: voiceProfile,
                    voiceCloneService: voiceCloneService
                )

                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].audioURL = audioURL
                    }
                }
            } catch {
                // Voice generation failed - not critical
            }
        }
    }

    private func playAudio(for message: DigitalSelfMessage) {
        guard let audioURL = message.audioURL else { return }

        // Stop current playback
        audioPlayer?.stop()

        if playingMessageId == message.id {
            playingMessageId = nil
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayerDelegate = AudioPlayerDelegate()
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.play()
            playingMessageId = message.id
        } catch {
            // Playback failed
        }
    }

    private func saveConversation() {
        guard let config = config, !messages.isEmpty else { return }
        config.addConversation(contactId: contact.id, messages: messages)
        try? modelContext.save()
    }
}

// MARK: - Message Bubble

private struct DigitalSelfMessageBubble: View {
    let message: DigitalSelfMessage
    let soulProfile: SoulProfile?
    let avatarProfile: AvatarProfile?
    let contactName: String
    let isPlaying: Bool
    let onPlayAudio: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .digitalSelf {
                avatarView
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .digitalSelf ? .leading : .trailing, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .digitalSelf
                            ? Color(.secondarySystemBackground)
                            : Color.purple
                    )
                    .foregroundColor(message.role == .digitalSelf ? .primary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 8) {
                    if message.audioURL != nil {
                        Button {
                            onPlayAudio()
                        } label: {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.role == .user {
                userAvatar
            } else {
                Spacer()
            }
        }
    }

    private var avatarView: some View {
        ZStack {
            if let avatarProfile = avatarProfile,
               let photoData = avatarProfile.originalPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if let name = soulProfile?.nickname, let first = name.first {
                            Text(String(first).uppercased())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
    }

    private var userAvatar: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 36, height: 36)
            .overlay {
                Text(String(contactName.prefix(1)).uppercased())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let soulProfile: SoulProfile?
    let avatarProfile: AvatarProfile?

    @State private var animationOffset = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            ZStack {
                if let avatarProfile = avatarProfile,
                   let photoData = avatarProfile.originalPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white)
                        }
                }
            }

            // Typing dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset == index ? -4 : 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).repeatForever()) {
                    animationOffset = (animationOffset + 1) % 3
                }
            }

            Spacer()
        }
    }
}

// MARK: - Audio Player Delegate

private extension Notification.Name {
    static let digitalSelfAudioFinished = Notification.Name("digitalSelfAudioFinished")
}

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NotificationCenter.default.post(name: .digitalSelfAudioFinished, object: nil)
    }
}

#Preview {
    let contact = Contact(name: "Mom", relationship: .family)
    return DigitalSelfChatView(contact: contact)
        .modelContainer(for: [DigitalSelfConfig.self, SoulProfile.self, VoiceProfile.self, WritingStyleProfile.self, AvatarProfile.self, Contact.self], inMemory: true)
}
