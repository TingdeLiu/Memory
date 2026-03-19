import SwiftUI
import SwiftData
import Observation

@Observable
final class AIChatViewModel {
    var messages: [ChatMessage] = []
    var currentQuery: String = ""
    var isProcessing: Bool = false
    var error: AIServiceError?

    private var aiService: AIService
    private var modelContext: ModelContext

    init(aiService: AIService, modelContext: ModelContext) {
        self.aiService = aiService
        self.modelContext = modelContext
    }

    func sendMessage(allMemories: [MemoryEntry]) async {
        guard !currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userQuery = currentQuery
        let userMessage = ChatMessage(role: .user, content: userQuery)
        messages.append(userMessage)
        currentQuery = ""
        isProcessing = true
        error = nil

        do {
            // Fetch soul profile for personalized AI
            let soulProfile = fetchSoulProfile()

            // Build personalized system prompt
            let systemPrompt = AIService.personalizedSystemPrompt(soulProfile: soulProfile)

            // Use only non-private memories for context
            let contextMemories = allMemories.filter { !$0.isPrivate }
            let contextText = AIService.formatMemoriesForContext(contextMemories)

            // Build conversation with personalized context
            var apiMessages: [ChatMessage] = []

            if messages.count <= 1 {
                // First message: include memory context
                apiMessages.append(ChatMessage(
                    role: .user,
                    content: "Here are my memories for context:\n\n\(contextText)\n\nNow, please answer my question: \(userQuery)"
                ))
            } else {
                // Subsequent messages: send conversation history
                apiMessages = Array(messages.dropLast())
                apiMessages.append(ChatMessage(role: .user, content: userQuery))
            }

            let response = try await aiService.chat(messages: apiMessages, systemPrompt: systemPrompt)

            // Check for crisis keywords
            let finalResponse = AIService.appendCrisisInfoIfNeeded(to: response, query: userQuery)
            let aiMessage = ChatMessage(role: .assistant, content: finalResponse)
            messages.append(aiMessage)
        } catch let err as AIServiceError {
            self.error = err
        } catch {
            self.error = .networkError(error.localizedDescription)
        }

        isProcessing = false
    }

    func clearChat() {
        messages.removeAll()
        error = nil
    }

    // MARK: - Private

    private func fetchSoulProfile() -> SoulProfile? {
        let descriptor = FetchDescriptor<SoulProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
}
