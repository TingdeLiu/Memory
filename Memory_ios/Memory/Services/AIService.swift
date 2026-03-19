import Foundation
import SwiftData

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Codable {
    case claude
    case openAI
    case gemini
    case deepSeek
    case custom

    var name: String {
        switch self {
        case .claude: return "Claude"
        case .openAI: return "GPT"
        case .gemini: return "Gemini"
        case .deepSeek: return "DeepSeek"
        case .custom: return "Custom"
        }
    }

    var baseURL: String {
        switch self {
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .openAI: return "https://api.openai.com/v1/chat/completions"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-6"
        case .openAI: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        case .deepSeek: return "deepseek-chat"
        case .custom: return ""
        }
    }

    var availableModels: [String] {
        switch self {
        case .claude: return ["claude-sonnet-4-6", "claude-haiku-4-5-20251001", "claude-opus-4-6"]
        case .openAI: return ["gpt-4o", "gpt-4o-mini", "o3-mini"]
        case .gemini: return ["gemini-2.0-flash", "gemini-2.5-pro"]
        case .deepSeek: return ["deepseek-chat", "deepseek-reasoner"]
        case .custom: return []
        }
    }

    var keychainAccount: String {
        "ai-api-key-\(rawValue)"
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - AI Provider Protocol

private protocol AIProviderProtocol {
    func buildRequest(messages: [ChatMessage], systemPrompt: String, apiKey: String, model: String, baseURL: String) throws -> URLRequest
    func parseResponse(data: Data) throws -> String
}

// MARK: - Claude Provider

private struct ClaudeProvider: AIProviderProtocol {
    func buildRequest(messages: [ChatMessage], systemPrompt: String, apiKey: String, model: String, baseURL: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.networkError("Invalid URL: \(baseURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let messagePayloads = messages.filter { $0.role != .system }.map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messagePayloads,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AIServiceError.invalidResponse
        }
        return text
    }
}

// MARK: - OpenAI-Compatible Provider (OpenAI, DeepSeek, Custom)

private struct OpenAICompatibleProvider: AIProviderProtocol {
    func buildRequest(messages: [ChatMessage], systemPrompt: String, apiKey: String, model: String, baseURL: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.networkError("Invalid URL: \(baseURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messagePayloads: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messagePayloads += messages.filter { $0.role != .system }.map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messagePayloads,
            "max_tokens": 2048,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }
        return content
    }
}

// MARK: - Gemini Provider

private struct GeminiProvider: AIProviderProtocol {
    func buildRequest(messages: [ChatMessage], systemPrompt: String, apiKey: String, model: String, baseURL: String) throws -> URLRequest {
        let urlString = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.networkError("Invalid URL: \(urlString)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        var contents: [[String: Any]] = []
        for msg in messages where msg.role != .system {
            let role = msg.role == .user ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [["text": msg.content]],
            ])
        }

        var body: [String: Any] = ["contents": contents]
        if !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIServiceError.invalidResponse
        }
        return text
    }
}

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(Int)
    case networkError(String)
    case aiDisabled

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured. Please add your API key in AI Settings."
        case .invalidResponse:
            return "Received an unexpected response from the AI service."
        case .unauthorized:
            return "Invalid API key. Please check your API key in AI Settings."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "The AI service encountered an error (code \(code)). Please try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        case .aiDisabled:
            return "AI features are disabled. Enable them in Settings."
        }
    }
}

// MARK: - AI Service

@Observable
final class AIService {
    var isProcessing = false
    var error: AIServiceError?
    var currentResponse = ""
    var selectedProvider: AIProvider {
        get {
            AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "claude") ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider")
        }
    }

    var selectedModel: String {
        get {
            UserDefaults.standard.string(forKey: "aiModel") ?? selectedProvider.defaultModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiModel")
        }
    }

    var customBaseURL: String {
        get { UserDefaults.standard.string(forKey: "aiCustomBaseURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "aiCustomBaseURL") }
    }

    var customModelName: String {
        get { UserDefaults.standard.string(forKey: "aiCustomModel") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "aiCustomModel") }
    }

    private static let keychainService = "com.tyndall.memory.ai"

    // MARK: - System Prompt

    private static let baseSystemPrompt = """
    You are a gentle, empathetic memory companion within the Memory app. \
    Your role is to help users reflect on, organize, and understand their memories.

    Guidelines:
    - Be warm, thoughtful, and respectful of the user's emotions.
    - Reference specific details from the provided memory context when answering.
    - If the user asks about something not in their memories, say so honestly.
    - Never fabricate memories or events that aren't in the context.
    - Respond in the same language the user writes in.

    Safety rules:
    - Do NOT provide medical, legal, or financial advice. If asked, suggest consulting a professional.
    - If you detect signs of crisis or distress (mentions of self-harm, suicide, abuse), respond with empathy \
    and include crisis resources: National Suicide Prevention Lifeline: 988 (US), Crisis Text Line: Text HOME to 741741.
    - Do not encourage harmful or illegal activities.
    """

    /// Build a personalized system prompt that incorporates the user's soul profile.
    static func personalizedSystemPrompt(soulProfile: SoulProfile?) -> String {
        var prompt = baseSystemPrompt

        guard let profile = soulProfile else { return prompt }

        var personalContext: [String] = []

        if let mbti = profile.mbtiType {
            let type = MBTIType(rawValue: mbti)
            personalContext.append("The user's MBTI type is \(mbti) (\(type?.nickname ?? "")).")
            if type?.isIntrovert == true {
                personalContext.append("They tend to be introspective. Give them space and don't be overly enthusiastic.")
            }
        }

        if !profile.loveLanguages.isEmpty {
            let labels = profile.loveLanguages.compactMap { LoveLanguage(rawValue: $0)?.label }
            personalContext.append("Their love languages are: \(labels.joined(separator: ", ")).")
        }

        if !profile.valuesRanking.isEmpty {
            let topValues = profile.valuesRanking.prefix(3).compactMap { CoreValue(rawValue: $0)?.label }
            personalContext.append("Their top values are: \(topValues.joined(separator: ", ")).")
        }

        if let communication = profile.communicationStyle, !communication.isEmpty {
            personalContext.append("Communication style insight: \(communication)")
        }

        if let emotional = profile.emotionalPatterns, !emotional.isEmpty {
            personalContext.append("Emotional pattern insight: \(emotional)")
        }

        if !personalContext.isEmpty {
            prompt += "\n\nPersonalization (adapt your tone and approach based on this):\n"
            prompt += personalContext.joined(separator: "\n")
        }

        return prompt
    }

    // MARK: - Crisis Keywords

    static let crisisKeywords = [
        // English
        "suicide", "kill myself", "end my life", "want to die", "self-harm",
        "hurt myself", "don't want to live", "no reason to live",
        // Chinese (Simplified & Traditional)
        "自杀", "自殺", "不想活", "结束生命", "結束生命", "伤害自己", "傷害自己",
        "活不下去", "想死", "轻生", "輕生", "了结", "了結", "厌世", "厭世",
        // Japanese
        "死にたい", "自殺したい",
        // Korean
        "자살", "죽고 싶다",
    ]

    private static let crisisAppendix = """

    ---
    If you or someone you know is in crisis, please reach out for help:
    - National Suicide Prevention Lifeline: 988 (US)
    - Crisis Text Line: Text HOME to 741741
    - 全国24小时心理危机干预热线: 400-161-9995 (中国)
    - 北京心理危机研究与干预中心: 010-82951332
    - International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/
    """

    // MARK: - API Key Management

    func saveAPIKey(_ key: String, for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)

        guard !key.isEmpty else { return }

        var addQuery = query
        addQuery[kSecValueData as String] = Data(key.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func loadAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasAPIKey(for provider: AIProvider) -> Bool {
        loadAPIKey(for: provider) != nil
    }

    // MARK: - Core API Call

    private func provider(for aiProvider: AIProvider) -> any AIProviderProtocol {
        switch aiProvider {
        case .claude:
            return ClaudeProvider()
        case .openAI, .deepSeek, .custom:
            return OpenAICompatibleProvider()
        case .gemini:
            return GeminiProvider()
        }
    }

    private func resolveBaseURL() -> String {
        if selectedProvider == .custom {
            return customBaseURL
        }
        return selectedProvider.baseURL
    }

    private func resolveModel() -> String {
        if selectedProvider == .custom {
            return customModelName.isEmpty ? "default" : customModelName
        }
        return selectedModel
    }

    private func sendRequest(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = loadAPIKey(for: selectedProvider) else {
            throw AIServiceError.noAPIKey
        }

        let providerImpl = provider(for: selectedProvider)
        let request = try providerImpl.buildRequest(
            messages: messages,
            systemPrompt: Self.systemPrompt,
            apiKey: apiKey,
            model: resolveModel(),
            baseURL: resolveBaseURL()
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw AIServiceError.unauthorized
        case 429:
            throw AIServiceError.rateLimited
        case 500...599:
            throw AIServiceError.serverError(httpResponse.statusCode)
        default:
            throw AIServiceError.serverError(httpResponse.statusCode)
        }

        return try providerImpl.parseResponse(data: data)
    }

    // MARK: - Memory Context Formatting

    static func formatMemoriesForContext(_ memories: [MemoryEntry]) -> String {
        let filtered = memories.filter { !$0.isPrivate }
        guard !filtered.isEmpty else { return "No memories available." }

        return filtered.map { entry in
            var parts: [String] = []
            parts.append("Title: \(entry.title)")
            if !entry.content.isEmpty {
                parts.append("Content: \(entry.content)")
            }
            if let mood = entry.mood {
                parts.append("Mood: \(mood.emoji) \(mood.label)")
            }
            if !entry.tags.isEmpty {
                parts.append("Tags: \(entry.tags.joined(separator: ", "))")
            }
            parts.append("Date: \(entry.createdAt.formatted(date: .long, time: .shortened))")
            if let transcription = entry.transcription, !transcription.isEmpty {
                parts.append("Transcription: \(transcription)")
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n---\n")
    }

    static func appendCrisisInfoIfNeeded(to response: String, query: String) -> String {
        // Use localizedCaseInsensitiveContains for proper Unicode handling
        let needsCrisis = crisisKeywords.contains { keyword in
            query.localizedCaseInsensitiveContains(keyword)
        }
        if needsCrisis {
            return response + crisisAppendix
        }
        return response
    }

    // MARK: - Public Methods

    func summarizeMemories(_ memories: [MemoryEntry]) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            let context = Self.formatMemoriesForContext(memories)
            let message = ChatMessage(
                role: .user,
                content: """
                Here are my recent memories. Please provide a thoughtful summary that highlights key themes, \
                emotions, and important moments:

                \(context)
                """
            )
            let response = try await sendRequest(messages: [message])
            currentResponse = response
            return response
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    func chatAboutMemories(query: String, context: [MemoryEntry], conversationHistory: [ChatMessage] = []) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            let contextText = Self.formatMemoriesForContext(context)
            var messages = conversationHistory

            if messages.isEmpty {
                messages.append(ChatMessage(
                    role: .user,
                    content: "Here are my memories for context:\n\n\(contextText)\n\nNow, please answer my question: \(query)"
                ))
            } else {
                messages.append(ChatMessage(role: .user, content: query))
            }

            let response = try await sendRequest(messages: messages)
            let finalResponse = Self.appendCrisisInfoIfNeeded(to: response, query: query)
            currentResponse = finalResponse
            return finalResponse
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    func analyzeEmotionTrends(_ memories: [MemoryEntry]) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            let context = Self.formatMemoriesForContext(memories)
            let message = ChatMessage(
                role: .user,
                content: """
                Analyze the emotional trends in my memories. Look at how my moods have changed over time, \
                identify patterns, and provide insights about my emotional journey:

                \(context)
                """
            )
            let response = try await sendRequest(messages: [message])
            currentResponse = response
            return response
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    func generateAnnualReport(_ memories: [MemoryEntry]) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            let context = Self.formatMemoriesForContext(memories)
            let message = ChatMessage(
                role: .user,
                content: """
                Create a warm, reflective annual report based on my memories. Include sections for key themes, \
                memorable moments, emotional highlights, and a look-ahead. Make it personal and meaningful:

                \(context)
                """
            )
            let response = try await sendRequest(messages: [message])
            currentResponse = response
            return response
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    /// Test the connection with the currently selected provider.
    func testConnection() async throws -> Bool {
        let message = ChatMessage(role: .user, content: "Hello! Please respond with just: Connection successful.")
        _ = try await sendRequest(messages: [message])
        return true
    }

    /// Check if the AI service is configured with an API key.
    var isConfigured: Bool {
        loadAPIKey(for: selectedProvider) != nil
    }

    /// Send a message with custom system prompt (for use by other services).
    func sendMessage(
        userMessage: String,
        systemPrompt: String,
        conversationHistory: [ChatMessage] = []
    ) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            var messages = conversationHistory
            if !systemPrompt.isEmpty {
                messages.insert(ChatMessage(role: .system, content: systemPrompt), at: 0)
            }
            messages.append(ChatMessage(role: .user, content: userMessage))
            let response = try await sendRequest(messages: messages)
            currentResponse = response
            return response
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    /// Simple chat method for quick prompts (convenience wrapper).
    func chat(prompt: String, memories: [MemoryEntry] = []) async throws -> String {
        let context = memories.isEmpty ? "" : Self.formatMemoriesForContext(memories)
        let fullPrompt = context.isEmpty ? prompt : "\(prompt)\n\nContext:\n\(context)"
        return try await sendMessage(userMessage: fullPrompt, systemPrompt: "You are a helpful AI assistant.", conversationHistory: [])
    }

    /// Chat with full conversation history and custom system prompt.
    func chat(messages: [ChatMessage], systemPrompt: String) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            var allMessages = [ChatMessage(role: .system, content: systemPrompt)]
            allMessages.append(contentsOf: messages)
            let response = try await sendRequest(messages: allMessages)
            currentResponse = response
            return response
        } catch let err as AIServiceError {
            error = err
            throw err
        } catch {
            let serviceError = AIServiceError.networkError(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
}
