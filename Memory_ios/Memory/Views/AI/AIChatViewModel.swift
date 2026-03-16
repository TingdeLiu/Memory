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
            // Use only non-private memories for context
            let contextMemories = allMemories.filter { !$0.isPrivate }
            let response = try await aiService.chatAboutMemories(
                query: userQuery,
                context: contextMemories,
                conversationHistory: Array(messages.dropLast()) // Send history excluding the latest user message
            )
            
            let aiMessage = ChatMessage(role: .assistant, content: response)
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
}
