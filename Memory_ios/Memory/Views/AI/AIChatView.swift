import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var allMemories: [MemoryEntry]
    @State private var viewModel: AIChatViewModel?

    // Custom initializer to pass dependencies if needed
    init(aiService: AIService? = nil, modelContext: ModelContext? = nil) {
        if let aiService, let modelContext {
            _viewModel = State(initialValue: AIChatViewModel(aiService: aiService, modelContext: modelContext))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let vm = viewModel {
                    if vm.messages.isEmpty {
                        emptyState
                    } else {
                        messageList
                    }

                    Divider()
                    inputArea
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "aiChat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        viewModel?.clearChat()
                    } label: {
                        Label(String(localized: "aiChat.clear"), systemImage: "trash")
                    }
                    .disabled(viewModel?.messages.isEmpty ?? true)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = AIChatViewModel(aiService: AIService(), modelContext: modelContext)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(String(localized: "aiChat.welcome"))
                .font(.headline)
            
            Text(String(localized: "aiChat.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "aiChat.suggestions.title"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                suggestionButton(String(localized: "aiChat.suggestions.1"))
                suggestionButton(String(localized: "aiChat.suggestions.2"))
                suggestionButton(String(localized: "aiChat.suggestions.3"))
            }
            .padding(.top, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func suggestionButton(_ text: String) -> some View {
        Button {
            viewModel?.currentQuery = text
            Task {
                await viewModel?.sendMessage(allMemories: allMemories)
            }
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel?.messages ?? []) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel?.isProcessing == true {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(String(localized: "aiChat.processing"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .id("processing")
                    }

                    if let error = viewModel?.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.red)

                            Button(String(localized: "common.retry")) {
                                Task {
                                    await viewModel?.sendMessage(allMemories: allMemories)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel?.messages.count) {
                withAnimation {
                    proxy.scrollTo(viewModel?.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel?.isProcessing) {
                if viewModel?.isProcessing == true {
                    withAnimation {
                        proxy.scrollTo("processing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(String(localized: "aiChat.inputPlaceholder"), text: Binding(
                get: { viewModel?.currentQuery ?? "" },
                set: { viewModel?.currentQuery = $0 }
            ), axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)

            Button {
                Task {
                    await viewModel?.sendMessage(allMemories: allMemories)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(viewModel?.currentQuery.isEmpty ?? true || viewModel?.isProcessing ?? false)
        }
        .padding()
        .background(.background)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if message.role != .user { Spacer() }
        }
        .padding(.horizontal)
    }
}

#Preview {
    AIChatView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
