import Foundation
import SwiftData

@Model
final class AssessmentResult {
    var id: UUID
    var type: AssessmentType
    var status: AssessmentStatus
    var createdAt: Date
    var completedAt: Date?

    // MARK: - Raw Data

    var rawAnswers: Data?  // JSON encoded answers
    var resultCode: String?  // "INFJ", "quality_time", etc.
    var resultScores: Data?  // JSON encoded scores for multi-dimension assessments

    // MARK: - AI Analysis

    var _plainAnalysis: String?
    var _encryptedAnalysis: String?

    var analysis: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedAnalysis {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainAnalysis
        }
        set {
            _plainAnalysis = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedAnalysis = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedAnalysis = nil
            }
        }
    }

    init(type: AssessmentType) {
        self.id = UUID()
        self.type = type
        self.status = .inProgress
        self.createdAt = Date()
        self.completedAt = nil
        self.rawAnswers = nil
        self.resultCode = nil
        self.resultScores = nil
        self._plainAnalysis = nil
        self._encryptedAnalysis = nil
    }

    // MARK: - Computed Properties

    var isComplete: Bool { status == .completed }

    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(createdAt)
    }

    var mbtiType: MBTIType? {
        guard type == .mbti, let code = resultCode else { return nil }
        return MBTIType(rawValue: code)
    }

    var bigFiveScores: BigFiveScores? {
        guard type == .bigFive, let data = resultScores else { return nil }
        return try? JSONDecoder().decode(BigFiveScores.self, from: data)
    }

    var topLoveLanguages: [LoveLanguage] {
        guard type == .loveLanguage, let code = resultCode else { return [] }
        return code.split(separator: ",").compactMap { LoveLanguage(rawValue: String($0)) }
    }

    var rankedValues: [CoreValue] {
        guard type == .values, let code = resultCode else { return [] }
        return code.split(separator: ",").compactMap { CoreValue(rawValue: String($0)) }
    }

    // MARK: - Methods

    func setAnswers(_ answers: [Any]) {
        rawAnswers = try? JSONSerialization.data(withJSONObject: answers)
    }

    func complete(resultCode: String?, scores: Data? = nil, analysis: String? = nil) {
        self.resultCode = resultCode
        self.resultScores = scores
        self.analysis = analysis
        self.status = .completed
        self.completedAt = Date()
    }

    func abandon() {
        self.status = .abandoned
        self.completedAt = Date()
    }

    // MARK: - Migration Helpers

    func encryptAllFields() {
        if let a = _plainAnalysis {
            _encryptedAnalysis = EncryptedFieldHelper.encryptString(a, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let e = _encryptedAnalysis, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainAnalysis = d
        }
        _encryptedAnalysis = nil
    }
}

// MARK: - Assessment Type

enum AssessmentType: String, Codable, CaseIterable {
    case mbti
    case bigFive
    case loveLanguage
    case values
    case legacy

    var label: String {
        switch self {
        case .mbti: return "MBTI"
        case .bigFive: return String(localized: "assessment.bigfive")
        case .loveLanguage: return String(localized: "assessment.lovelanguage")
        case .values: return String(localized: "assessment.values")
        case .legacy: return String(localized: "legacy.title")
        }
    }

    var description: String {
        switch self {
        case .mbti: return String(localized: "assessment.mbti.desc")
        case .bigFive: return String(localized: "assessment.bigfive.desc")
        case .loveLanguage: return String(localized: "assessment.lovelanguage.desc")
        case .values: return String(localized: "assessment.values.desc")
        case .legacy: return String(localized: "legacy.desc")
        }
    }

    var icon: String {
        switch self {
        case .mbti: return "person.crop.circle.badge.questionmark"
        case .bigFive: return "pentagon.fill"
        case .loveLanguage: return "heart.text.square.fill"
        case .values: return "star.fill"
        case .legacy: return "leaf.fill"
        }
    }

    var questionCount: Int {
        switch self {
        case .mbti: return 20
        case .bigFive: return 44
        case .loveLanguage: return 15
        case .values: return 40
        case .legacy: return 5
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .mbti: return 5
        case .bigFive: return 10
        case .loveLanguage: return 4
        case .values: return 8
        case .legacy: return 5
        }
    }
}

// MARK: - Assessment Status

enum AssessmentStatus: String, Codable {
    case inProgress
    case completed
    case abandoned
}

// MARK: - MBTI Questions

struct MBTIQuestions {
    struct Question {
        let text: String
        let optionA: String
        let optionB: String
        let dimension: MBTIDimension
    }

    enum MBTIDimension {
        case EI  // Extraversion vs Introversion
        case SN  // Sensing vs Intuition
        case TF  // Thinking vs Feeling
        case JP  // Judging vs Perceiving
    }

    static let questions: [Question] = [
        // E/I Questions
        Question(
            text: String(localized: "mbti.q.ei.1"),
            optionA: String(localized: "mbti.q.ei.1.a"),
            optionB: String(localized: "mbti.q.ei.1.b"),
            dimension: .EI
        ),
        Question(
            text: String(localized: "mbti.q.ei.2"),
            optionA: String(localized: "mbti.q.ei.2.a"),
            optionB: String(localized: "mbti.q.ei.2.b"),
            dimension: .EI
        ),
        Question(
            text: String(localized: "mbti.q.ei.3"),
            optionA: String(localized: "mbti.q.ei.3.a"),
            optionB: String(localized: "mbti.q.ei.3.b"),
            dimension: .EI
        ),
        Question(
            text: String(localized: "mbti.q.ei.4"),
            optionA: String(localized: "mbti.q.ei.4.a"),
            optionB: String(localized: "mbti.q.ei.4.b"),
            dimension: .EI
        ),
        Question(
            text: String(localized: "mbti.q.ei.5"),
            optionA: String(localized: "mbti.q.ei.5.a"),
            optionB: String(localized: "mbti.q.ei.5.b"),
            dimension: .EI
        ),
        // S/N Questions
        Question(
            text: String(localized: "mbti.q.sn.1"),
            optionA: String(localized: "mbti.q.sn.1.a"),
            optionB: String(localized: "mbti.q.sn.1.b"),
            dimension: .SN
        ),
        Question(
            text: String(localized: "mbti.q.sn.2"),
            optionA: String(localized: "mbti.q.sn.2.a"),
            optionB: String(localized: "mbti.q.sn.2.b"),
            dimension: .SN
        ),
        Question(
            text: String(localized: "mbti.q.sn.3"),
            optionA: String(localized: "mbti.q.sn.3.a"),
            optionB: String(localized: "mbti.q.sn.3.b"),
            dimension: .SN
        ),
        Question(
            text: String(localized: "mbti.q.sn.4"),
            optionA: String(localized: "mbti.q.sn.4.a"),
            optionB: String(localized: "mbti.q.sn.4.b"),
            dimension: .SN
        ),
        Question(
            text: String(localized: "mbti.q.sn.5"),
            optionA: String(localized: "mbti.q.sn.5.a"),
            optionB: String(localized: "mbti.q.sn.5.b"),
            dimension: .SN
        ),
        // T/F Questions
        Question(
            text: String(localized: "mbti.q.tf.1"),
            optionA: String(localized: "mbti.q.tf.1.a"),
            optionB: String(localized: "mbti.q.tf.1.b"),
            dimension: .TF
        ),
        Question(
            text: String(localized: "mbti.q.tf.2"),
            optionA: String(localized: "mbti.q.tf.2.a"),
            optionB: String(localized: "mbti.q.tf.2.b"),
            dimension: .TF
        ),
        Question(
            text: String(localized: "mbti.q.tf.3"),
            optionA: String(localized: "mbti.q.tf.3.a"),
            optionB: String(localized: "mbti.q.tf.3.b"),
            dimension: .TF
        ),
        Question(
            text: String(localized: "mbti.q.tf.4"),
            optionA: String(localized: "mbti.q.tf.4.a"),
            optionB: String(localized: "mbti.q.tf.4.b"),
            dimension: .TF
        ),
        Question(
            text: String(localized: "mbti.q.tf.5"),
            optionA: String(localized: "mbti.q.tf.5.a"),
            optionB: String(localized: "mbti.q.tf.5.b"),
            dimension: .TF
        ),
        // J/P Questions
        Question(
            text: String(localized: "mbti.q.jp.1"),
            optionA: String(localized: "mbti.q.jp.1.a"),
            optionB: String(localized: "mbti.q.jp.1.b"),
            dimension: .JP
        ),
        Question(
            text: String(localized: "mbti.q.jp.2"),
            optionA: String(localized: "mbti.q.jp.2.a"),
            optionB: String(localized: "mbti.q.jp.2.b"),
            dimension: .JP
        ),
        Question(
            text: String(localized: "mbti.q.jp.3"),
            optionA: String(localized: "mbti.q.jp.3.a"),
            optionB: String(localized: "mbti.q.jp.3.b"),
            dimension: .JP
        ),
        Question(
            text: String(localized: "mbti.q.jp.4"),
            optionA: String(localized: "mbti.q.jp.4.a"),
            optionB: String(localized: "mbti.q.jp.4.b"),
            dimension: .JP
        ),
        Question(
            text: String(localized: "mbti.q.jp.5"),
            optionA: String(localized: "mbti.q.jp.5.a"),
            optionB: String(localized: "mbti.q.jp.5.b"),
            dimension: .JP
        ),
    ]

    /// Calculate MBTI type from answers (true = option A, false = option B)
    static func calculateType(answers: [Bool]) -> String? {
        guard answers.count == 20 else { return nil }

        var scores: [MBTIDimension: Int] = [.EI: 0, .SN: 0, .TF: 0, .JP: 0]

        for (index, answer) in answers.enumerated() {
            let dimension = questions[index].dimension
            if answer { // Option A selected
                scores[dimension, default: 0] += 1
            }
        }

        let E = scores[.EI, default: 0] >= 3 ? "E" : "I"
        let S = scores[.SN, default: 0] >= 3 ? "S" : "N"
        let T = scores[.TF, default: 0] >= 3 ? "T" : "F"
        let J = scores[.JP, default: 0] >= 3 ? "J" : "P"

        return E + S + T + J
    }
}

// MARK: - Love Language Questions

struct LoveLanguageQuestions {
    struct Question {
        let text: String
        let optionA: (String, LoveLanguage)
        let optionB: (String, LoveLanguage)
    }

    static let questions: [Question] = [
        Question(
            text: String(localized: "love.q.1"),
            optionA: (String(localized: "love.q.1.a"), .wordsOfAffirmation),
            optionB: (String(localized: "love.q.1.b"), .physicalTouch)
        ),
        Question(
            text: String(localized: "love.q.2"),
            optionA: (String(localized: "love.q.2.a"), .qualityTime),
            optionB: (String(localized: "love.q.2.b"), .receivingGifts)
        ),
        Question(
            text: String(localized: "love.q.3"),
            optionA: (String(localized: "love.q.3.a"), .actsOfService),
            optionB: (String(localized: "love.q.3.b"), .wordsOfAffirmation)
        ),
        Question(
            text: String(localized: "love.q.4"),
            optionA: (String(localized: "love.q.4.a"), .physicalTouch),
            optionB: (String(localized: "love.q.4.b"), .qualityTime)
        ),
        Question(
            text: String(localized: "love.q.5"),
            optionA: (String(localized: "love.q.5.a"), .receivingGifts),
            optionB: (String(localized: "love.q.5.b"), .actsOfService)
        ),
        Question(
            text: String(localized: "love.q.6"),
            optionA: (String(localized: "love.q.6.a"), .wordsOfAffirmation),
            optionB: (String(localized: "love.q.6.b"), .qualityTime)
        ),
        Question(
            text: String(localized: "love.q.7"),
            optionA: (String(localized: "love.q.7.a"), .actsOfService),
            optionB: (String(localized: "love.q.7.b"), .physicalTouch)
        ),
        Question(
            text: String(localized: "love.q.8"),
            optionA: (String(localized: "love.q.8.a"), .qualityTime),
            optionB: (String(localized: "love.q.8.b"), .receivingGifts)
        ),
        Question(
            text: String(localized: "love.q.9"),
            optionA: (String(localized: "love.q.9.a"), .physicalTouch),
            optionB: (String(localized: "love.q.9.b"), .wordsOfAffirmation)
        ),
        Question(
            text: String(localized: "love.q.10"),
            optionA: (String(localized: "love.q.10.a"), .receivingGifts),
            optionB: (String(localized: "love.q.10.b"), .actsOfService)
        ),
        Question(
            text: String(localized: "love.q.11"),
            optionA: (String(localized: "love.q.11.a"), .wordsOfAffirmation),
            optionB: (String(localized: "love.q.11.b"), .actsOfService)
        ),
        Question(
            text: String(localized: "love.q.12"),
            optionA: (String(localized: "love.q.12.a"), .qualityTime),
            optionB: (String(localized: "love.q.12.b"), .physicalTouch)
        ),
        Question(
            text: String(localized: "love.q.13"),
            optionA: (String(localized: "love.q.13.a"), .receivingGifts),
            optionB: (String(localized: "love.q.13.b"), .wordsOfAffirmation)
        ),
        Question(
            text: String(localized: "love.q.14"),
            optionA: (String(localized: "love.q.14.a"), .actsOfService),
            optionB: (String(localized: "love.q.14.b"), .qualityTime)
        ),
        Question(
            text: String(localized: "love.q.15"),
            optionA: (String(localized: "love.q.15.a"), .physicalTouch),
            optionB: (String(localized: "love.q.15.b"), .receivingGifts)
        ),
    ]

    /// Calculate top love languages from answers (true = option A, false = option B)
    static func calculateResult(answers: [Bool]) -> [LoveLanguage] {
        guard answers.count == questions.count else { return [] }

        var scores: [LoveLanguage: Int] = [:]
        for lang in LoveLanguage.allCases {
            scores[lang] = 0
        }

        for (index, answer) in answers.enumerated() {
            let question = questions[index]
            let selected = answer ? question.optionA.1 : question.optionB.1
            scores[selected, default: 0] += 1
        }

        return scores.sorted { $0.value > $1.value }
            .prefix(2)
            .map { $0.key }
    }
}

// MARK: - Legacy Questions

struct LegacyQuestions {
    static let questions: [String] = [
        String(localized: "legacy.q.1"),
        String(localized: "legacy.q.2"),
        String(localized: "legacy.q.3"),
        String(localized: "legacy.q.4"),
        String(localized: "legacy.q.5")
    ]
}
