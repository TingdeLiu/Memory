import Foundation
import SwiftData

@Model
final class WritingStyleProfile {
    var id: UUID

    // Analysis status
    var status: WritingStyleStatus
    var lastAnalyzedAt: Date?
    var memoriesAnalyzed: Int
    var totalWordsAnalyzed: Int

    // Vocabulary analysis (JSON)
    var topWordsData: Data?         // [String: Int] - word frequencies
    var topPhrasesData: Data?       // [String: Int] - phrase frequencies
    var avgSentenceLength: Double?
    var avgParagraphLength: Double?

    // AI-generated descriptions
    var styleDescription: String?    // Overall writing style
    var toneDescription: String?     // Tone characteristics
    var vocabularyLevel: String?     // Vocabulary richness
    var emotionalExpression: String? // How emotions are expressed
    var uniqueTraits: String?        // Unique writing traits

    // Sample texts (representative examples)
    var sampleTextsData: Data?       // [String] JSON

    // Settings
    var isEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    init() {
        self.id = UUID()
        self.status = .notAnalyzed
        self.lastAnalyzedAt = nil
        self.memoriesAnalyzed = 0
        self.totalWordsAnalyzed = 0
        self.topWordsData = nil
        self.topPhrasesData = nil
        self.avgSentenceLength = nil
        self.avgParagraphLength = nil
        self.styleDescription = nil
        self.toneDescription = nil
        self.vocabularyLevel = nil
        self.emotionalExpression = nil
        self.uniqueTraits = nil
        self.sampleTextsData = nil
        self.isEnabled = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var isReady: Bool { status == .ready }

    var canAnalyze: Bool { status != .analyzing }

    var topWords: [String: Int] {
        get {
            guard let data = topWordsData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            topWordsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    var topPhrases: [String: Int] {
        get {
            guard let data = topPhrasesData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            topPhrasesData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    var sampleTexts: [String] {
        get {
            guard let data = sampleTextsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            sampleTextsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    var sortedTopWords: [(word: String, count: Int)] {
        topWords.sorted { $0.value > $1.value }.map { (word: $0.key, count: $0.value) }
    }

    var sortedTopPhrases: [(phrase: String, count: Int)] {
        topPhrases.sorted { $0.value > $1.value }.map { (phrase: $0.key, count: $0.value) }
    }

    var statusDescription: String {
        switch status {
        case .notAnalyzed:
            return String(localized: "writing.status.not_analyzed")
        case .analyzing:
            return String(localized: "writing.status.analyzing")
        case .ready:
            return String(localized: "writing.status.ready")
        case .failed:
            return String(localized: "writing.status.failed")
        }
    }

    var hasEnoughData: Bool {
        memoriesAnalyzed >= 5 && totalWordsAnalyzed >= 500
    }

    // MARK: - Methods

    func startAnalysis() {
        status = .analyzing
        updatedAt = Date()
    }

    func completeAnalysis(memoriesCount: Int, wordsCount: Int) {
        status = .ready
        memoriesAnalyzed = memoriesCount
        totalWordsAnalyzed = wordsCount
        lastAnalyzedAt = Date()
        updatedAt = Date()
    }

    func failAnalysis() {
        status = .failed
        updatedAt = Date()
    }

    func reset() {
        status = .notAnalyzed
        lastAnalyzedAt = nil
        memoriesAnalyzed = 0
        totalWordsAnalyzed = 0
        topWordsData = nil
        topPhrasesData = nil
        avgSentenceLength = nil
        avgParagraphLength = nil
        styleDescription = nil
        toneDescription = nil
        vocabularyLevel = nil
        emotionalExpression = nil
        uniqueTraits = nil
        sampleTextsData = nil
        updatedAt = Date()
    }
}

// MARK: - Writing Style Status

enum WritingStyleStatus: String, Codable {
    case notAnalyzed = "not_analyzed"
    case analyzing = "analyzing"
    case ready = "ready"
    case failed = "failed"

    var icon: String {
        switch self {
        case .notAnalyzed: return "pencil.and.outline"
        case .analyzing: return "gearshape.2"
        case .ready: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .notAnalyzed: return "secondary"
        case .analyzing: return "orange"
        case .ready: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Writing Style Constants

enum WritingStyleConstants {
    static let minimumMemories = 5
    static let minimumWords = 500
    static let recommendedMemories = 20
    static let recommendedWords = 2000

    static let topWordsLimit = 50
    static let topPhrasesLimit = 30
    static let sampleTextsLimit = 5

    // Stop words to exclude from analysis (Chinese + English)
    static let stopWords: Set<String> = [
        // Chinese
        "的", "了", "是", "在", "我", "有", "和", "就", "不", "人",
        "都", "一", "一个", "上", "也", "很", "到", "说", "要", "去",
        "你", "会", "着", "没有", "看", "好", "自己", "这", "那", "她",
        "他", "它", "们", "什么", "为", "这个", "那个", "但", "还", "能",
        // English
        "the", "a", "an", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will",
        "would", "could", "should", "may", "might", "must", "shall",
        "can", "need", "dare", "ought", "used", "to", "of", "in",
        "for", "on", "with", "at", "by", "from", "as", "into", "through",
        "during", "before", "after", "above", "below", "between", "under",
        "again", "further", "then", "once", "here", "there", "when",
        "where", "why", "how", "all", "each", "few", "more", "most",
        "other", "some", "such", "no", "nor", "not", "only", "own",
        "same", "so", "than", "too", "very", "just", "and", "but",
        "if", "or", "because", "as", "until", "while", "of", "at",
        "by", "for", "with", "about", "against", "between", "into",
        "through", "during", "before", "after", "above", "below", "to",
        "from", "up", "down", "in", "out", "on", "off", "over", "under",
        "i", "me", "my", "myself", "we", "our", "ours", "ourselves",
        "you", "your", "yours", "yourself", "yourselves", "he", "him",
        "his", "himself", "she", "her", "hers", "herself", "it", "its",
        "itself", "they", "them", "their", "theirs", "themselves",
        "what", "which", "who", "whom", "this", "that", "these", "those",
        "am", "is", "are", "was", "were", "be", "been", "being"
    ]
}

// MARK: - Occasion Types for Draft Generation

enum WritingOccasion: String, CaseIterable {
    case birthday = "birthday"
    case holiday = "holiday"
    case gratitude = "gratitude"
    case apology = "apology"
    case encouragement = "encouragement"
    case farewell = "farewell"
    case congratulations = "congratulations"
    case comfort = "comfort"
    case love = "love"
    case custom = "custom"

    var label: String {
        switch self {
        case .birthday: return String(localized: "writing.occasion.birthday")
        case .holiday: return String(localized: "writing.occasion.holiday")
        case .gratitude: return String(localized: "writing.occasion.gratitude")
        case .apology: return String(localized: "writing.occasion.apology")
        case .encouragement: return String(localized: "writing.occasion.encouragement")
        case .farewell: return String(localized: "writing.occasion.farewell")
        case .congratulations: return String(localized: "writing.occasion.congratulations")
        case .comfort: return String(localized: "writing.occasion.comfort")
        case .love: return String(localized: "writing.occasion.love")
        case .custom: return String(localized: "writing.occasion.custom")
        }
    }

    var icon: String {
        switch self {
        case .birthday: return "birthday.cake"
        case .holiday: return "gift"
        case .gratitude: return "heart.text.square"
        case .apology: return "hand.raised"
        case .encouragement: return "hands.clap"
        case .farewell: return "hand.wave"
        case .congratulations: return "party.popper"
        case .comfort: return "heart"
        case .love: return "heart.fill"
        case .custom: return "square.and.pencil"
        }
    }

    var promptHint: String {
        switch self {
        case .birthday: return String(localized: "writing.hint.birthday")
        case .holiday: return String(localized: "writing.hint.holiday")
        case .gratitude: return String(localized: "writing.hint.gratitude")
        case .apology: return String(localized: "writing.hint.apology")
        case .encouragement: return String(localized: "writing.hint.encouragement")
        case .farewell: return String(localized: "writing.hint.farewell")
        case .congratulations: return String(localized: "writing.hint.congratulations")
        case .comfort: return String(localized: "writing.hint.comfort")
        case .love: return String(localized: "writing.hint.love")
        case .custom: return String(localized: "writing.hint.custom")
        }
    }
}
