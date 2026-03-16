import Foundation
import SwiftData

@Observable
final class SoulService {
    static let shared = SoulService()

    var isAnalyzing = false
    var analysisProgress: Double = 0.0
    var lastError: String?

    private init() {}

    // MARK: - Profile Management

    /// Get or create the soul profile (singleton per user)
    @MainActor
    func getOrCreateProfile(context: ModelContext) -> SoulProfile {
        let descriptor = FetchDescriptor<SoulProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = SoulProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Get or create relationship profile for a contact
    @MainActor
    func getOrCreateRelationshipProfile(for contact: Contact, context: ModelContext) -> RelationshipProfile {
        let contactId = contact.id
        let descriptor = FetchDescriptor<RelationshipProfile>(
            predicate: #Predicate { $0.contact?.id == contactId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = RelationshipProfile(contact: contact)
        context.insert(profile)
        try? context.save()
        return profile
    }

    // MARK: - Memory Analysis

    /// Analyze all memories to extract insights
    @MainActor
    func analyzeMemories(
        profile: SoulProfile,
        memories: [MemoryEntry],
        aiService: AIService,
        context: ModelContext
    ) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        analysisProgress = 0.0
        lastError = nil

        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }

        // Filter out private memories if not allowed
        let allowPrivate = UserDefaults.standard.bool(forKey: "aiAllowPrivateMemories")
        let filteredMemories = memories.filter { !$0.isPrivate || allowPrivate }

        guard !filteredMemories.isEmpty else {
            lastError = String(localized: "soul.error.no_memories")
            return
        }

        // Prepare memory context
        let memoryContext = buildMemoryContext(filteredMemories)

        do {
            // Generate personality insights
            analysisProgress = 0.2
            let personalityPrompt = """
            Based on the following memories, analyze the person's personality traits, tendencies, and characteristics.
            Focus on:
            - Communication style (formal/casual, verbose/concise)
            - Emotional patterns (how they express feelings)
            - Values that emerge from their stories
            - Interests and passions
            - Thinking style (logical/intuitive, big-picture/detail-oriented)

            Memories:
            \(memoryContext)

            Provide a thoughtful, nuanced analysis in Markdown format. Be specific and cite examples from the memories.
            """

            profile.personalityInsights = try await aiService.chat(prompt: personalityPrompt, memories: [])
            analysisProgress = 0.4

            // Generate life story summary
            let storyPrompt = """
            Based on the following memories, write a brief narrative of this person's life story.
            Focus on key themes, important moments, and the journey they've been on.
            Write in third person, warmly and respectfully.

            Memories:
            \(memoryContext)

            Write the story in Markdown format, organized by life themes rather than chronologically.
            """

            profile.lifeStory = try await aiService.chat(prompt: storyPrompt, memories: [])
            analysisProgress = 0.6

            // Generate emotional patterns
            let emotionalPrompt = """
            Analyze the emotional patterns in these memories:
            - What emotions appear most frequently?
            - What triggers positive emotions?
            - What triggers negative emotions?
            - How do they process difficult experiences?
            - What brings them peace or joy?

            Memories:
            \(memoryContext)

            Provide insights in Markdown format.
            """

            profile.emotionalPatterns = try await aiService.chat(prompt: emotionalPrompt, memories: [])
            analysisProgress = 0.8

            // Identify core memories
            let corePrompt = """
            From these memories, identify the 5-10 most significant "core memories" that define this person.
            For each, explain why it seems particularly important to their identity.

            Memories:
            \(memoryContext)

            List them in Markdown format with brief explanations.
            """

            profile.coreMemories = try await aiService.chat(prompt: corePrompt, memories: [])

            profile.lastMemoryAnalysisDate = Date()
            profile.updateCompleteness()
            try? context.save()

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Analyze relationship with a contact
    @MainActor
    func analyzeRelationship(
        profile: RelationshipProfile,
        contact: Contact,
        memories: [MemoryEntry],
        messages: [Message],
        aiService: AIService,
        context: ModelContext
    ) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        analysisProgress = 0.0
        lastError = nil

        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }

        let contactName = contact.name

        // Find memories mentioning this contact
        let relatedMemories = memories.filter { memory in
            let content = memory.content.lowercased()
            let title = memory.title.lowercased()
            let name = contactName.lowercased()
            return content.contains(name) || title.contains(name) ||
                   memory.tags.contains(where: { $0.lowercased().contains(name) })
        }

        let memoryContext = buildMemoryContext(relatedMemories)
        let messageContext = buildMessageContext(messages)

        do {
            // Shared memories summary
            analysisProgress = 0.25
            if !relatedMemories.isEmpty {
                let sharedPrompt = """
                Summarize the shared memories and experiences with \(contactName) based on these entries:

                \(memoryContext)

                Write a warm narrative in Markdown format.
                """
                profile.sharedMemoriesSummary = try await aiService.chat(prompt: sharedPrompt, memories: [])
            }

            // Relationship dynamics
            analysisProgress = 0.5
            let dynamicsPrompt = """
            Based on the memories and messages about \(contactName), describe the relationship dynamics:
            - What role does this person play in the user's life?
            - How would you characterize their bond?
            - What are the key themes in their relationship?

            Memories: \(memoryContext)
            Messages: \(messageContext)

            Write in Markdown format.
            """
            profile.relationshipDynamics = try await aiService.chat(prompt: dynamicsPrompt, memories: [])

            // Things they love about this person
            analysisProgress = 0.75
            let lovePrompt = """
            Based on the memories and messages, what does the user seem to love or appreciate most about \(contactName)?
            Be specific and heartfelt.

            Memories: \(memoryContext)
            Messages: \(messageContext)

            List in Markdown format.
            """
            profile.thingsILove = try await aiService.chat(prompt: lovePrompt, memories: [])

            // Generate "Our Story"
            let storyPrompt = """
            Write a brief narrative of the relationship between the user and \(contactName).
            Include how they met (if known), key moments, and what makes this relationship special.

            Memories: \(memoryContext)
            Messages: \(messageContext)

            Write warmly in Markdown format.
            """
            profile.ourStory = try await aiService.chat(prompt: storyPrompt, memories: [])

            profile.lastAnalysisDate = Date()
            profile.updateCompleteness()
            try? context.save()

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Assessment Processing

    /// Process Big Five assessment result
    @MainActor
    func processBigFiveResult(
        profile: SoulProfile,
        result: AssessmentResult,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard let scoresData = result.resultScores,
              let scores = try? JSONDecoder().decode(BigFiveScores.self, from: scoresData) else { return }

        profile.bigFiveScores = scoresData
        profile.bigFiveDate = Date()

        // Generate personalized analysis
        do {
            let prompt = """
            The user's Big Five personality scores (0.0 to 1.0) are:
            - Openness: \(scores.openness)
            - Conscientiousness: \(scores.conscientiousness)
            - Extraversion: \(scores.extraversion)
            - Agreeableness: \(scores.agreeableness)
            - Neuroticism: \(scores.neuroticism)

            Based on these scores and any personality insights we have:
            \(profile.personalityInsights ?? "No additional context.")

            Provide a personalized interpretation of what these traits mean for them specifically.
            - How do these traits manifest in their life?
            - What are their strengths and potential blind spots?
            - How can they leverage their personality for growth?

            Write in Markdown format, addressing the user directly with warmth and depth.
            """

            result.analysis = try await aiService.chat(prompt: prompt, memories: [])
            try? context.save()
        } catch {
            // Fallback
        }

        profile.assessmentCount += 1
        profile.updateCompleteness()
        try? context.save()
    }

    /// Process Relationship analysis (legacy questions)
    @MainActor
    func processLegacyResult(
        profile: SoulProfile,
        result: AssessmentResult,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard let data = result.rawAnswers,
              let answers = try? JSONDecoder().decode([String].self, from: data) else { return }

        // Generate personalized analysis for legacy entries
        do {
            let questions = LegacyQuestions.questions
            var qaText = ""
            for i in 0..<min(questions.count, answers.count) {
                if !answers[i].isEmpty {
                    qaText += "Q: \(questions[i])\nA: \(answers[i])\n\n"
                }
            }

            let prompt = """
            The user has shared their thoughts on life meaning and legacy:
            
            \(qaText)

            Analyze these reflections and provide:
            1. A summary of their core life philosophy
            2. What they value most as their legacy
            3. A supportive and inspiring closing thought based on their entries

            Write in Markdown format, very personally and respectfully.
            """

            result.analysis = try await aiService.chat(prompt: prompt, memories: [])
            
            // Integrate into values and beliefs
            if let currentValues = profile.valuesAndBeliefs {
                profile.valuesAndBeliefs = currentValues + "\n\n### Life Meaning & Legacy\n" + (result.analysis ?? "")
            } else {
                profile.valuesAndBeliefs = result.analysis
            }
            
            try? context.save()
        } catch {
            // Fallback
        }

        profile.assessmentCount += 1
        profile.updateCompleteness()
        try? context.save()
    }
    @MainActor
    func processMBTIResult(
        profile: SoulProfile,
        result: AssessmentResult,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard let mbtiCode = result.resultCode else { return }

        profile.mbtiType = mbtiCode
        profile.mbtiDate = Date()

        // Generate personalized analysis
        do {
            let prompt = """
            The user's MBTI type is \(mbtiCode).
            Based on this and any personality insights we have:
            \(profile.personalityInsights ?? "No additional context.")

            Provide a personalized interpretation of what this MBTI type means for them specifically.
            Don't just list generic traits - connect it to their actual personality patterns if available.

            Write in Markdown format, addressing the user directly.
            """

            result.analysis = try await aiService.chat(prompt: prompt, memories: [])
            try? context.save()
        } catch {
            result.analysis = MBTIType(rawValue: mbtiCode)?.description
        }

        profile.assessmentCount += 1
        profile.updateCompleteness()
        try? context.save()
    }

    /// Process Love Language assessment result
    @MainActor
    func processLoveLanguageResult(
        profile: SoulProfile,
        result: AssessmentResult,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard let codes = result.resultCode else { return }

        let languages = codes.split(separator: ",").map(String.init)
        profile.loveLanguages = languages
        profile.loveLanguageDate = Date()

        // Generate personalized analysis
        do {
            let languageNames = languages.compactMap { LoveLanguage(rawValue: $0)?.label }.joined(separator: ", ")
            let prompt = """
            The user's primary love languages are: \(languageNames).

            Provide practical insights on:
            1. How they prefer to receive love and appreciation
            2. How they naturally express love to others
            3. Tips for their relationships based on these preferences

            Write in Markdown format, warmly and specifically.
            """

            result.analysis = try await aiService.chat(prompt: prompt, memories: [])
            try? context.save()
        } catch {
            // Fallback to generic description
        }

        profile.assessmentCount += 1
        profile.updateCompleteness()
        try? context.save()
    }

    /// Process Values ranking result
    @MainActor
    func processValuesResult(
        profile: SoulProfile,
        result: AssessmentResult,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard let codes = result.resultCode else { return }

        let values = codes.split(separator: ",").map(String.init)
        profile.valuesRanking = values
        profile.valuesDate = Date()

        // Generate personalized analysis
        do {
            let valueNames = values.prefix(5).compactMap { CoreValue(rawValue: $0)?.label }.joined(separator: ", ")
            let prompt = """
            The user's top values are: \(valueNames).

            Analyze what this hierarchy of values suggests about:
            1. What drives their decisions
            2. What they prioritize in life
            3. Potential sources of fulfillment
            4. Potential sources of conflict (when values compete)

            Write in Markdown format with practical insights.
            """

            result.analysis = try await aiService.chat(prompt: prompt, memories: [])
            profile.valuesAndBeliefs = result.analysis
            try? context.save()
        } catch {
            // Fallback
        }

        profile.assessmentCount += 1
        profile.updateCompleteness()
        try? context.save()
    }

    // MARK: - Interview Processing

    /// Process completed interview and extract insights
    @MainActor
    func processInterview(
        interview: InterviewSession,
        profile: SoulProfile,
        aiService: AIService,
        context: ModelContext
    ) async {
        guard interview.isComplete else { return }

        // Build Q&A pairs
        var qaText = ""
        for i in 0..<min(interview.questions.count, interview.answers.count) {
            qaText += "Q: \(interview.questions[i])\nA: \(interview.answers[i])\n\n"
        }

        do {
            let prompt = """
            Extract key insights from this interview conversation:

            \(qaText)

            Summarize:
            1. Key facts learned about the person
            2. Personality traits revealed
            3. Values or beliefs expressed
            4. Important people or events mentioned

            Write concisely in Markdown format.
            """

            interview.insights = try await aiService.chat(prompt: prompt, memories: [])

            profile.interviewCount += 1
            profile.lastInterviewDate = Date()
            profile.updateCompleteness()
            try? context.save()

        } catch {
            interview.insights = "Unable to generate insights."
        }
    }

    // MARK: - Helpers

    private func buildMemoryContext(_ memories: [MemoryEntry]) -> String {
        let sorted = memories.sorted { $0.createdAt > $1.createdAt }
        let recent = sorted.prefix(50)  // Limit context size

        return recent.map { memory in
            let date = memory.createdAt.formatted(date: .abbreviated, time: .omitted)
            let mood = memory.mood?.emoji ?? ""
            let tags = memory.tags.joined(separator: ", ")
            return """
            [\(date)] \(mood) \(memory.title)
            \(memory.content)
            Tags: \(tags)
            ---
            """
        }.joined(separator: "\n")
    }

    private func buildMessageContext(_ messages: [Message]) -> String {
        let sorted = messages.sorted { $0.createdAt > $1.createdAt }
        let recent = sorted.prefix(20)

        return recent.map { message in
            let date = message.createdAt.formatted(date: .abbreviated, time: .omitted)
            let condition = message.deliveryCondition.label
            return """
            [\(date)] To be delivered: \(condition)
            \(message.content)
            ---
            """
        }.joined(separator: "\n")
    }
}
