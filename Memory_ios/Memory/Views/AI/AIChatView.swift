import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var allMemories: [MemoryEntry]
    @State private var aiService = AIService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var showingSettings = false
    @AppStorage("aiEnabled") private var aiEnabled = false

    private var contextMemories: [MemoryEntry] {
        Array(allMemories.filter { !$0.isPrivate }.prefix(50))
    }

    private var isConfigured: Bool {
        StoreService.shared.canUseAI && aiEnabled && aiService.hasAPIKey(for: aiService.selectedProvider)
    }

    private var needsPremium: Bool {
        !StoreService.shared.canUseAI
    }

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured {
                    setupPrompt
                } else {
                    chatContent
                }
            }
            .navigationTitle(String(localized: "aiChat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isConfigured {
                        Text(aiService.selectedProvider.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    AISettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "common.done")) { showingSettings = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Setup Prompt

    @State private var showingPurchase = false

    private var setupPrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: needsPremium ? "star.fill" : "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(needsPremium ? .yellow.opacity(0.6) : .accent.opacity(0.6))

            VStack(spacing: 8) {
                Text(needsPremium ? String(localized: "aiChat.premiumFeature") : String(localized: "aiChat.setup"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(needsPremium
                    ? String(localized: "aiChat.premiumDescription")
                    : String(localized: "aiChat.setupDescription"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if needsPremium {
                Button {
                    showingPurchase = true
                } label: {
                    Label(String(localized: "aiChat.upgradePremium"), systemImage: "star.fill")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    showingSettings = true
                } label: {
                    Label(String(localized: "aiChat.openSettings"), systemImage: "gearshape")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Welcome message
                        if messages.isEmpty {
                            welcomeSection
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if aiService.isProcessing {
                            typingIndicator
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
            inputBar
        }
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .padding(.top, 24)

            Text(String(localized: "aiChat.welcome"))
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                quickQuestion(String(localized: "aiChat.quick.summarize"))
                quickQuestion(String(localized: "aiChat.quick.feeling"))
                quickQuestion(String(localized: "aiChat.quick.themes"))
            }
            .padding(.bottom, 8)
        }
    }

    private func quickQuestion(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "aiChat.quickHint"))
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField(String(localized: "aiChat.inputPlaceholder"), text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isProcessing)
            .accessibilityLabel(String(localized: "aiChat.send"))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Send

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        Task {
            do {
                let response = try await aiService.chatAboutMemories(
                    query: text,
                    context: contextMemories,
                    conversationHistory: messages.filter { $0.role != .system }
                )
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: L10n.aiChatError(error.localizedDescription)
                )
                messages.append(errorMessage)
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    Text("AI")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.accentColor : Color(.systemGray6))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label(String(localized: "common.copy"), systemImage: "doc.on.doc")
                        }
                    }

                if message.role == .assistant {
                    Text(String(localized: "aiChat.aiGenerated"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? String(localized: "aiChat.you") : String(localized: "aiChat.ai")): \(message.content)")
    }
}

#Preview {
    AIChatView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
