import Foundation
import SwiftData

@Observable
final class InterviewService {
    var currentSession: InterviewSession?
    var currentQuestionIndex: Int = 0
    var isWaitingForAI = false
    var pendingQuestions: [String] = []

    private var aiService: AIService?
    private var modelContext: ModelContext?

    // MARK: - Session Management

    /// Start a new interview session
    @MainActor
    func startInterview(
        type: InterviewType,
        topic: InterviewTopic? = nil,
        aiService: AIService,
        context: ModelContext
    ) -> InterviewSession {
        self.aiService = aiService
        self.modelContext = context

        let session = InterviewSession(type: type, topic: topic)
        context.insert(session)

        // Load initial questions
        switch type {
        case .onboarding:
            pendingQuestions = OnboardingQuestions.questions
        case .deepDive:
            if let topic = topic {
                pendingQuestions = topic.sampleQuestions
            }
        case .periodic:
            pendingQuestions = periodicCheckInQuestions()
        case .milestone:
            pendingQuestions = milestoneQuestions()
        case .relationship:
            // Relationship questions are loaded separately with contact name
            pendingQuestions = []
        }

        currentSession = session
        currentQuestionIndex = 0

        // Add first question
        if let firstQuestion = pendingQuestions.first {
            session.addQuestion(firstQuestion)
        }

        try? context.save()
        return session
    }

    /// Start a relationship interview for a specific contact
    @MainActor
    func startRelationshipInterview(
        contact: Contact,
        aiService: AIService,
        context: ModelContext
    ) -> InterviewSession {
        self.aiService = aiService
        self.modelContext = context

        let session = InterviewSession(type: .relationship, topic: nil)
        context.insert(session)

        pendingQuestions = RelationshipInterviewQuestions.questions(
            for: contact.relationship,
            name: contact.name
        )

        currentSession = session
        currentQuestionIndex = 0

        if let firstQuestion = pendingQuestions.first {
            session.addQuestion(firstQuestion)
        }

        try? context.save()
        return session
    }

    /// Submit an answer and get the next question
    @MainActor
    func submitAnswer(_ answer: String) async -> String? {
        guard let session = currentSession,
              let aiService = aiService,
              let context = modelContext else { return nil }

        // Record the answer
        session.addAnswer(answer)
        currentQuestionIndex += 1

        // Check if we have more pre-defined questions
        if currentQuestionIndex < pendingQuestions.count {
            let nextQuestion = pendingQuestions[currentQuestionIndex]
            session.addQuestion(nextQuestion)
            try? context.save()
            return nextQuestion
        }

        // Generate follow-up question using AI
        isWaitingForAI = true
        defer { isWaitingForAI = false }

        // Build conversation history
        var history = ""
        for i in 0..<min(session.questions.count, session.answers.count) {
            history += "Q: \(session.questions[i])\nA: \(session.answers[i])\n\n"
        }

        // Decide if we should continue or wrap up
        let shouldContinue = session.questionCount < maxQuestionsForType(session.type)

        if shouldContinue {
            do {
                let prompt = """
                You are conducting a warm, empathetic interview to help someone record their memories and life story.

                Interview type: \(session.type.label)
                \(session.topic.map { "Topic: \($0.label)" } ?? "")

                Conversation so far:
                \(history)

                Based on their last answer, ask a thoughtful follow-up question that:
                - Shows you were listening
                - Gently encourages them to share more
                - Explores interesting details they mentioned
                - Stays on topic but follows their lead

                Respond with ONLY the next question, nothing else. Be warm and conversational.
                """

                let nextQuestion = try await aiService.chat(prompt: prompt, memories: [])
                session.addQuestion(nextQuestion)
                try? context.save()
                return nextQuestion

            } catch {
                // Fallback: end the interview
                return nil
            }
        }

        return nil  // Interview complete
    }

    /// Complete the current interview
    @MainActor
    func completeInterview() async {
        guard let session = currentSession,
              let aiService = aiService,
              let context = modelContext else { return }

        isWaitingForAI = true
        defer { isWaitingForAI = false }

        // Generate insights from the interview
        var history = ""
        for i in 0..<min(session.questions.count, session.answers.count) {
            history += "Q: \(session.questions[i])\nA: \(session.answers[i])\n\n"
        }

        do {
            let prompt = """
            Summarize the key insights from this interview:

            \(history)

            Extract:
            1. Key facts about the person
            2. Important people mentioned
            3. Significant life events or memories
            4. Values or beliefs expressed
            5. Emotional themes

            Be concise but comprehensive. Write in Markdown format.
            """

            let insights = try await aiService.chat(prompt: prompt, memories: [])
            session.complete(withInsights: insights)
        } catch {
            session.complete(withInsights: nil)
        }

        try? context.save()
        currentSession = nil
        currentQuestionIndex = 0
        pendingQuestions = []
    }

    /// Skip the current interview
    @MainActor
    func skipInterview() {
        guard let session = currentSession,
              let context = modelContext else { return }

        session.skip()
        try? context.save()

        currentSession = nil
        currentQuestionIndex = 0
        pendingQuestions = []
    }

    /// Skip the current question and move to the next
    @MainActor
    func skipQuestion() async -> String? {
        guard let session = currentSession else { return nil }

        // Record skip as empty answer
        session.addAnswer("[skipped]")
        currentQuestionIndex += 1

        // Get next question
        if currentQuestionIndex < pendingQuestions.count {
            let nextQuestion = pendingQuestions[currentQuestionIndex]
            session.addQuestion(nextQuestion)
            try? modelContext?.save()
            return nextQuestion
        }

        return nil
    }

    // MARK: - Question Sets

    private func periodicCheckInQuestions() -> [String] {
        [
            String(localized: "periodic.q.recent"),
            String(localized: "periodic.q.feeling"),
            String(localized: "periodic.q.thinking"),
            String(localized: "periodic.q.grateful"),
            String(localized: "periodic.q.want_to_remember")
        ]
    }

    private func milestoneQuestions() -> [String] {
        [
            String(localized: "milestone.q.milestone"),
            String(localized: "milestone.q.feeling"),
            String(localized: "milestone.q.changed"),
            String(localized: "milestone.q.learned"),
            String(localized: "milestone.q.future"),
            String(localized: "milestone.q.share")
        ]
    }

    private func maxQuestionsForType(_ type: InterviewType) -> Int {
        switch type {
        case .onboarding: return 8
        case .periodic: return 6
        case .milestone: return 10
        case .deepDive: return 12
        case .relationship: return 10
        }
    }

    // MARK: - Computed Properties

    var currentQuestion: String? {
        currentSession?.questions.last
    }

    var progress: Double {
        guard let session = currentSession else { return 0 }
        let maxQuestions = maxQuestionsForType(session.type)
        return Double(session.questionCount) / Double(maxQuestions)
    }

    var isActive: Bool {
        currentSession != nil && currentSession?.status == .inProgress
    }

    var answeredCount: Int {
        currentSession?.answerCount ?? 0
    }
}

// MARK: - Onboarding Interview Flow

extension InterviewService {
    /// Check if user needs onboarding interview
    @MainActor
    func needsOnboardingInterview(context: ModelContext) -> Bool {
        let targetType = InterviewType.onboarding
        let targetStatus = InterviewStatus.completed
        let descriptor = FetchDescriptor<InterviewSession>(
            predicate: #Predicate { $0.type == targetType && $0.status == targetStatus }
        )
        let completed = (try? context.fetch(descriptor).count) ?? 0
        return completed == 0
    }

    /// Check if it's time for a periodic check-in
    @MainActor
    func needsPeriodicInterview(context: ModelContext) -> Bool {
        let targetType = InterviewType.periodic
        let descriptor = FetchDescriptor<InterviewSession>(
            predicate: #Predicate { $0.type == targetType },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let lastInterview = try? context.fetch(descriptor).first else {
            return true  // Never done one
        }

        // Suggest periodic interview weekly
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return lastInterview.createdAt < weekAgo
    }
}

// MARK: - AI-Powered Dynamic Questions

extension InterviewService {
    /// Generate a question based on user's profile and recent activity
    @MainActor
    func generateContextualQuestion(
        profile: SoulProfile,
        recentMemories: [MemoryEntry],
        aiService: AIService
    ) async -> String? {
        guard !recentMemories.isEmpty else { return nil }

        let memoryContext = recentMemories.prefix(5).map { memory in
            "[\(memory.createdAt.formatted(date: .abbreviated, time: .omitted))] \(memory.title): \(memory.content.prefix(100))..."
        }.joined(separator: "\n")

        do {
            let prompt = """
            Based on this person's recent memories:
            \(memoryContext)

            And what we know about them:
            - Name: \(profile.displayName)
            - MBTI: \(profile.mbtiType ?? "unknown")

            Generate a thoughtful question to help them reflect and share more about their life.
            The question should:
            - Reference something specific from their recent entries
            - Encourage deeper reflection
            - Be warm and non-intrusive

            Respond with ONLY the question.
            """

            return try await aiService.chat(prompt: prompt, memories: [])
        } catch {
            return nil
        }
    }
}
