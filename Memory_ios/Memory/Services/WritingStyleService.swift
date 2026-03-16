import Foundation
import SwiftData

@Observable
final class WritingStyleService {
    static let shared = WritingStyleService()

    var isAnalyzing = false
    var analysisProgress: Double = 0.0
    var isGenerating = false
    var lastError: String?

    private init() {}

    // MARK: - Text Analysis

    /// Analyze writing style from memories
    func analyzeStyle(
        profile: WritingStyleProfile,
        memories: [MemoryEntry],
        aiService: AIService
    ) async throws {
        guard !memories.isEmpty else {
            throw WritingStyleError.noMemories
        }

        isAnalyzing = true
        analysisProgress = 0.0
        lastError = nil
        profile.startAnalysis()

        defer { isAnalyzing = false }

        // Extract text content from memories
        let texts = memories.compactMap { memory -> String? in
            let content = memory.content
            return content.isEmpty ? nil : content
        }

        guard !texts.isEmpty else {
            profile.failAnalysis()
            throw WritingStyleError.noContent
        }

        analysisProgress = 0.1

        // Combine all texts
        let combinedText = texts.joined(separator: "\n\n")
        let totalWords = countWords(in: combinedText)

        // Basic statistics
        analysisProgress = 0.2

        // Extract word frequencies
        let wordFreq = extractWordFrequencies(from: texts)
        profile.topWords = Dictionary(uniqueKeysWithValues: wordFreq.prefix(WritingStyleConstants.topWordsLimit))

        analysisProgress = 0.3

        // Extract phrase frequencies
        let phraseFreq = extractPhraseFrequencies(from: texts)
        profile.topPhrases = Dictionary(uniqueKeysWithValues: phraseFreq.prefix(WritingStyleConstants.topPhrasesLimit))

        analysisProgress = 0.4

        // Calculate sentence and paragraph lengths
        let (avgSentence, avgParagraph) = calculateTextMetrics(from: texts)
        profile.avgSentenceLength = avgSentence
        profile.avgParagraphLength = avgParagraph

        analysisProgress = 0.5

        // Select representative sample texts
        profile.sampleTexts = selectSampleTexts(from: texts, limit: WritingStyleConstants.sampleTextsLimit)

        analysisProgress = 0.6

        // Use AI to generate style descriptions
        do {
            let styleAnalysis = try await generateStyleAnalysis(
                texts: texts,
                wordFreq: wordFreq,
                phraseFreq: phraseFreq,
                aiService: aiService
            )

            profile.styleDescription = styleAnalysis.style
            profile.toneDescription = styleAnalysis.tone
            profile.vocabularyLevel = styleAnalysis.vocabulary
            profile.emotionalExpression = styleAnalysis.emotional
            profile.uniqueTraits = styleAnalysis.unique

            analysisProgress = 1.0
            profile.completeAnalysis(memoriesCount: memories.count, wordsCount: totalWords)

        } catch {
            profile.failAnalysis()
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Word Frequency Analysis

    private func extractWordFrequencies(from texts: [String]) -> [(String, Int)] {
        var wordCounts: [String: Int] = [:]

        for text in texts {
            let words = tokenize(text)
            for word in words {
                let lower = word.lowercased()
                if !WritingStyleConstants.stopWords.contains(lower) && word.count >= 2 {
                    wordCounts[lower, default: 0] += 1
                }
            }
        }

        return wordCounts.sorted { $0.value > $1.value }
    }

    private func extractPhraseFrequencies(from texts: [String]) -> [(String, Int)] {
        var phraseCounts: [String: Int] = [:]

        for text in texts {
            let words = tokenize(text)

            // Extract 2-word phrases
            for i in 0..<max(0, words.count - 1) {
                let phrase = "\(words[i]) \(words[i + 1])"
                let lowerPhrase = phrase.lowercased()

                // Skip if contains stop words
                let phraseWords = lowerPhrase.split(separator: " ").map(String.init)
                if phraseWords.allSatisfy({ !WritingStyleConstants.stopWords.contains($0) }) {
                    phraseCounts[lowerPhrase, default: 0] += 1
                }
            }

            // Extract 3-word phrases
            for i in 0..<max(0, words.count - 2) {
                let phrase = "\(words[i]) \(words[i + 1]) \(words[i + 2])"
                let lowerPhrase = phrase.lowercased()

                let phraseWords = lowerPhrase.split(separator: " ").map(String.init)
                if phraseWords.allSatisfy({ !WritingStyleConstants.stopWords.contains($0) }) {
                    phraseCounts[lowerPhrase, default: 0] += 1
                }
            }
        }

        // Filter to phrases that appear at least twice
        return phraseCounts.filter { $0.value >= 2 }.sorted { $0.value > $1.value }
    }

    private func tokenize(_ text: String) -> [String] {
        // Handle both Chinese and English text
        var words: [String] = []

        // Use linguistic tagger for better tokenization
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        let range = NSRange(location: 0, length: text.utf16.count)
        tagger.enumerateTags(in: range, scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { _, tokenRange, _, _ in
            if let swiftRange = Range(tokenRange, in: text) {
                let word = String(text[swiftRange])
                if !word.isEmpty {
                    words.append(word)
                }
            }
        }

        return words
    }

    private func countWords(in text: String) -> Int {
        tokenize(text).count
    }

    private func calculateTextMetrics(from texts: [String]) -> (avgSentence: Double, avgParagraph: Double) {
        var totalSentences = 0
        var totalSentenceLength = 0
        var totalParagraphs = 0
        var totalParagraphLength = 0

        for text in texts {
            // Split into paragraphs
            let paragraphs = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            totalParagraphs += paragraphs.count

            for paragraph in paragraphs {
                let words = tokenize(paragraph)
                totalParagraphLength += words.count

                // Split into sentences (rough approximation)
                let sentences = paragraph.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                totalSentences += sentences.count

                for sentence in sentences {
                    totalSentenceLength += tokenize(sentence).count
                }
            }
        }

        let avgSentence = totalSentences > 0 ? Double(totalSentenceLength) / Double(totalSentences) : 0
        let avgParagraph = totalParagraphs > 0 ? Double(totalParagraphLength) / Double(totalParagraphs) : 0

        return (avgSentence, avgParagraph)
    }

    private func selectSampleTexts(from texts: [String], limit: Int) -> [String] {
        // Select diverse, medium-length texts as samples
        let sortedByLength = texts.sorted { $0.count < $1.count }
        let midStart = max(0, sortedByLength.count / 4)
        let midEnd = min(sortedByLength.count, sortedByLength.count * 3 / 4)

        let middleTexts = Array(sortedByLength[midStart..<midEnd])

        // Take evenly spaced samples
        var samples: [String] = []
        let step = max(1, middleTexts.count / limit)

        for i in stride(from: 0, to: middleTexts.count, by: step) {
            if samples.count < limit {
                let text = middleTexts[i]
                // Truncate very long texts
                if text.count > 500 {
                    samples.append(String(text.prefix(500)) + "...")
                } else {
                    samples.append(text)
                }
            }
        }

        return samples
    }

    // MARK: - AI Style Analysis

    private struct StyleAnalysisResult {
        var style: String
        var tone: String
        var vocabulary: String
        var emotional: String
        var unique: String
    }

    private func generateStyleAnalysis(
        texts: [String],
        wordFreq: [(String, Int)],
        phraseFreq: [(String, Int)],
        aiService: AIService
    ) async throws -> StyleAnalysisResult {
        // Prepare sample texts for AI
        let sampleTexts = texts.prefix(10).joined(separator: "\n---\n")

        // Prepare word frequency summary
        let topWords = wordFreq.prefix(20).map { "\($0.0): \($0.1)" }.joined(separator: ", ")
        let topPhrases = phraseFreq.prefix(10).map { "\($0.0): \($0.1)" }.joined(separator: ", ")

        let prompt = """
        Analyze the following writing samples and provide a detailed writing style profile.

        ## Writing Samples:
        \(sampleTexts)

        ## Word Frequency (top 20):
        \(topWords)

        ## Common Phrases (top 10):
        \(topPhrases)

        Please analyze and provide the following in JSON format:
        {
            "style": "Overall writing style description (2-3 sentences)",
            "tone": "Tone characteristics - formal/casual, serious/humorous, etc. (1-2 sentences)",
            "vocabulary": "Vocabulary level and characteristics (1-2 sentences)",
            "emotional": "How emotions are expressed in writing (1-2 sentences)",
            "unique": "Unique traits or patterns in this person's writing (1-2 sentences)"
        }

        Respond ONLY with the JSON, no other text.
        """

        let systemPrompt = """
        You are a writing style analyst. Analyze the given text samples and identify the author's unique writing characteristics.
        Focus on patterns, word choice, sentence structure, and emotional expression.
        Be specific and insightful. Respond in the same language as the writing samples.
        """

        let response = try await aiService.sendMessage(
            userMessage: prompt,
            systemPrompt: systemPrompt,
            conversationHistory: []
        )

        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            // Fallback: use the response as style description
            return StyleAnalysisResult(
                style: response,
                tone: "",
                vocabulary: "",
                emotional: "",
                unique: ""
            )
        }

        return StyleAnalysisResult(
            style: json["style"] ?? "",
            tone: json["tone"] ?? "",
            vocabulary: json["vocabulary"] ?? "",
            emotional: json["emotional"] ?? "",
            unique: json["unique"] ?? ""
        )
    }

    // MARK: - Text Generation

    /// Generate text in user's writing style
    func generateInStyle(
        prompt: String,
        profile: WritingStyleProfile,
        aiService: AIService
    ) async throws -> String {
        guard profile.isReady else {
            throw WritingStyleError.profileNotReady
        }

        isGenerating = true
        defer { isGenerating = false }

        let styleContext = buildStyleContext(profile: profile)

        let systemPrompt = """
        You are a writing assistant that mimics a specific person's writing style.

        ## Writing Style Profile:
        \(styleContext)

        ## Instructions:
        - Write in the exact same style, tone, and vocabulary as described above
        - Use similar sentence structures and emotional expressions
        - Match the formality level and unique traits
        - The output should sound like it was written by this person
        - Write in the same language as the sample texts
        """

        let response = try await aiService.sendMessage(
            userMessage: prompt,
            systemPrompt: systemPrompt,
            conversationHistory: []
        )

        return response
    }

    /// Generate a message draft for a specific contact and occasion
    func generateDraft(
        for contact: Contact,
        occasion: WritingOccasion,
        customPrompt: String? = nil,
        profile: WritingStyleProfile,
        aiService: AIService
    ) async throws -> String {
        guard profile.isReady else {
            throw WritingStyleError.profileNotReady
        }

        isGenerating = true
        defer { isGenerating = false }

        let styleContext = buildStyleContext(profile: profile)

        let occasionPrompt: String
        if occasion == .custom, let custom = customPrompt {
            occasionPrompt = custom
        } else {
            occasionPrompt = occasion.promptHint
        }

        let userPrompt = """
        Write a message to \(contact.name) (\(contact.relationship.rawValue)).
        Occasion: \(occasion.label)
        Context: \(occasionPrompt)

        Write a heartfelt, personal message in the specified writing style.
        Keep it natural and authentic to how this person would actually write.
        """

        let systemPrompt = """
        You are helping someone write a personal message in their own writing style.

        ## Writing Style Profile:
        \(styleContext)

        ## Instructions:
        - Write exactly as this person would write
        - Keep the message personal and heartfelt
        - Use their vocabulary and sentence patterns
        - Match their emotional expression style
        - Length should be appropriate for the occasion (2-4 paragraphs typical)
        - Write in the language the person normally uses
        """

        let response = try await aiService.sendMessage(
            userMessage: userPrompt,
            systemPrompt: systemPrompt,
            conversationHistory: []
        )

        return response
    }

    private func buildStyleContext(profile: WritingStyleProfile) -> String {
        var context = ""

        if let style = profile.styleDescription, !style.isEmpty {
            context += "Overall Style: \(style)\n"
        }
        if let tone = profile.toneDescription, !tone.isEmpty {
            context += "Tone: \(tone)\n"
        }
        if let vocab = profile.vocabularyLevel, !vocab.isEmpty {
            context += "Vocabulary: \(vocab)\n"
        }
        if let emotional = profile.emotionalExpression, !emotional.isEmpty {
            context += "Emotional Expression: \(emotional)\n"
        }
        if let unique = profile.uniqueTraits, !unique.isEmpty {
            context += "Unique Traits: \(unique)\n"
        }

        // Add top words and phrases
        let topWords = profile.sortedTopWords.prefix(15).map { $0.word }.joined(separator: ", ")
        if !topWords.isEmpty {
            context += "Frequently Used Words: \(topWords)\n"
        }

        let topPhrases = profile.sortedTopPhrases.prefix(10).map { $0.phrase }.joined(separator: "; ")
        if !topPhrases.isEmpty {
            context += "Common Phrases: \(topPhrases)\n"
        }

        // Add sample texts
        let samples = profile.sampleTexts.prefix(3).joined(separator: "\n---\n")
        if !samples.isEmpty {
            context += "\nSample Writing:\n\(samples)\n"
        }

        return context
    }
}

// MARK: - Errors

enum WritingStyleError: LocalizedError {
    case noMemories
    case noContent
    case profileNotReady
    case analysisError(String)
    case generationError(String)

    var errorDescription: String? {
        switch self {
        case .noMemories:
            return String(localized: "writing.error.no_memories")
        case .noContent:
            return String(localized: "writing.error.no_content")
        case .profileNotReady:
            return String(localized: "writing.error.not_ready")
        case .analysisError(let message):
            return message
        case .generationError(let message):
            return message
        }
    }
}
