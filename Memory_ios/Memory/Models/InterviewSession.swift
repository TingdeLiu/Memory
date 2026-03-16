import Foundation
import SwiftData

@Model
final class InterviewSession {
    var id: UUID
    var type: InterviewType
    var topic: InterviewTopic?
    var status: InterviewStatus
    var createdAt: Date
    var completedAt: Date?

    // MARK: - Conversation Data

    var _plainQuestions: [String]
    var _plainAnswers: [String]
    var _plainInsights: String?

    var _encryptedQuestions: String?
    var _encryptedAnswers: String?
    var _encryptedInsights: String?

    // MARK: - Transparent Accessors

    var questions: [String] {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedQuestions {
                return EncryptedFieldHelper.decryptStringArray(encrypted, recordId: id) ?? _plainQuestions
            }
            return _plainQuestions
        }
        set {
            _plainQuestions = newValue
            if EncryptionLevel.current == .full {
                _encryptedQuestions = EncryptedFieldHelper.encryptStringArray(newValue, recordId: id)
            }
        }
    }

    var answers: [String] {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedAnswers {
                return EncryptedFieldHelper.decryptStringArray(encrypted, recordId: id) ?? _plainAnswers
            }
            return _plainAnswers
        }
        set {
            _plainAnswers = newValue
            if EncryptionLevel.current == .full {
                _encryptedAnswers = EncryptedFieldHelper.encryptStringArray(newValue, recordId: id)
            }
        }
    }

    var insights: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedInsights {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainInsights
        }
        set {
            _plainInsights = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedInsights = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedInsights = nil
            }
        }
    }

    init(type: InterviewType, topic: InterviewTopic? = nil) {
        self.id = UUID()
        self.type = type
        self.topic = topic
        self.status = .inProgress
        self.createdAt = Date()
        self.completedAt = nil
        self._plainQuestions = []
        self._plainAnswers = []
        self._plainInsights = nil
        self._encryptedQuestions = nil
        self._encryptedAnswers = nil
        self._encryptedInsights = nil
    }

    // MARK: - Computed Properties

    var questionCount: Int { questions.count }

    var answerCount: Int { answers.count }

    var currentQuestionIndex: Int { answerCount }

    var isComplete: Bool { status == .completed }

    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(createdAt)
    }

    // MARK: - Methods

    func addQuestion(_ question: String) {
        var q = questions
        q.append(question)
        questions = q
    }

    func addAnswer(_ answer: String) {
        var a = answers
        a.append(answer)
        answers = a
    }

    func complete(withInsights insights: String?) {
        self.insights = insights
        self.status = .completed
        self.completedAt = Date()
    }

    func skip() {
        self.status = .skipped
        self.completedAt = Date()
    }

    // MARK: - Migration Helpers

    func encryptAllFields() {
        _encryptedQuestions = EncryptedFieldHelper.encryptStringArray(_plainQuestions, recordId: id)
        _encryptedAnswers = EncryptedFieldHelper.encryptStringArray(_plainAnswers, recordId: id)
        if let i = _plainInsights {
            _encryptedInsights = EncryptedFieldHelper.encryptString(i, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let e = _encryptedQuestions, let d = EncryptedFieldHelper.decryptStringArray(e, recordId: id) {
            _plainQuestions = d
        }
        if let e = _encryptedAnswers, let d = EncryptedFieldHelper.decryptStringArray(e, recordId: id) {
            _plainAnswers = d
        }
        if let e = _encryptedInsights, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainInsights = d
        }
        _encryptedQuestions = nil
        _encryptedAnswers = nil
        _encryptedInsights = nil
    }
}

// MARK: - Interview Type

enum InterviewType: String, Codable, CaseIterable {
    case onboarding      // First-time user introduction
    case periodic        // Regular check-in
    case milestone       // Birthday, anniversary, life events
    case deepDive        // Focused topic exploration
    case relationship    // About a specific person

    var label: String {
        switch self {
        case .onboarding: return String(localized: "interview.type.onboarding")
        case .periodic: return String(localized: "interview.type.periodic")
        case .milestone: return String(localized: "interview.type.milestone")
        case .deepDive: return String(localized: "interview.type.deepdive")
        case .relationship: return String(localized: "interview.type.relationship")
        }
    }

    var icon: String {
        switch self {
        case .onboarding: return "hand.wave.fill"
        case .periodic: return "calendar.badge.clock"
        case .milestone: return "star.fill"
        case .deepDive: return "magnifyingglass"
        case .relationship: return "person.2.fill"
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .onboarding: return 5
        case .periodic: return 3
        case .milestone: return 10
        case .deepDive: return 15
        case .relationship: return 10
        }
    }
}

// MARK: - Interview Topic

enum InterviewTopic: String, Codable, CaseIterable {
    case childhood
    case family
    case education
    case career
    case loveLife
    case friendship
    case dreams
    case fears
    case regrets
    case beliefs
    case death
    case legacy

    var label: String {
        switch self {
        case .childhood: return String(localized: "interview.topic.childhood")
        case .family: return String(localized: "interview.topic.family")
        case .education: return String(localized: "interview.topic.education")
        case .career: return String(localized: "interview.topic.career")
        case .loveLife: return String(localized: "interview.topic.love")
        case .friendship: return String(localized: "interview.topic.friendship")
        case .dreams: return String(localized: "interview.topic.dreams")
        case .fears: return String(localized: "interview.topic.fears")
        case .regrets: return String(localized: "interview.topic.regrets")
        case .beliefs: return String(localized: "interview.topic.beliefs")
        case .death: return String(localized: "interview.topic.death")
        case .legacy: return String(localized: "interview.topic.legacy")
        }
    }

    var description: String {
        switch self {
        case .childhood: return String(localized: "interview.topic.childhood.desc")
        case .family: return String(localized: "interview.topic.family.desc")
        case .education: return String(localized: "interview.topic.education.desc")
        case .career: return String(localized: "interview.topic.career.desc")
        case .loveLife: return String(localized: "interview.topic.love.desc")
        case .friendship: return String(localized: "interview.topic.friendship.desc")
        case .dreams: return String(localized: "interview.topic.dreams.desc")
        case .fears: return String(localized: "interview.topic.fears.desc")
        case .regrets: return String(localized: "interview.topic.regrets.desc")
        case .beliefs: return String(localized: "interview.topic.beliefs.desc")
        case .death: return String(localized: "interview.topic.death.desc")
        case .legacy: return String(localized: "interview.topic.legacy.desc")
        }
    }

    var icon: String {
        switch self {
        case .childhood: return "figure.and.child.holdinghands"
        case .family: return "house.fill"
        case .education: return "graduationcap.fill"
        case .career: return "briefcase.fill"
        case .loveLife: return "heart.fill"
        case .friendship: return "person.2.fill"
        case .dreams: return "sparkles"
        case .fears: return "cloud.bolt.fill"
        case .regrets: return "arrow.uturn.backward"
        case .beliefs: return "lightbulb.fill"
        case .death: return "leaf.fill"
        case .legacy: return "gift.fill"
        }
    }

    var sampleQuestions: [String] {
        switch self {
        case .childhood:
            return [
                String(localized: "interview.q.childhood.1"),
                String(localized: "interview.q.childhood.2"),
                String(localized: "interview.q.childhood.3")
            ]
        case .family:
            return [
                String(localized: "interview.q.family.1"),
                String(localized: "interview.q.family.2"),
                String(localized: "interview.q.family.3")
            ]
        case .education:
            return [
                String(localized: "interview.q.education.1"),
                String(localized: "interview.q.education.2"),
                String(localized: "interview.q.education.3")
            ]
        case .career:
            return [
                String(localized: "interview.q.career.1"),
                String(localized: "interview.q.career.2"),
                String(localized: "interview.q.career.3")
            ]
        case .loveLife:
            return [
                String(localized: "interview.q.love.1"),
                String(localized: "interview.q.love.2"),
                String(localized: "interview.q.love.3")
            ]
        case .friendship:
            return [
                String(localized: "interview.q.friendship.1"),
                String(localized: "interview.q.friendship.2"),
                String(localized: "interview.q.friendship.3")
            ]
        case .dreams:
            return [
                String(localized: "interview.q.dreams.1"),
                String(localized: "interview.q.dreams.2"),
                String(localized: "interview.q.dreams.3")
            ]
        case .fears:
            return [
                String(localized: "interview.q.fears.1"),
                String(localized: "interview.q.fears.2"),
                String(localized: "interview.q.fears.3")
            ]
        case .regrets:
            return [
                String(localized: "interview.q.regrets.1"),
                String(localized: "interview.q.regrets.2"),
                String(localized: "interview.q.regrets.3")
            ]
        case .beliefs:
            return [
                String(localized: "interview.q.beliefs.1"),
                String(localized: "interview.q.beliefs.2"),
                String(localized: "interview.q.beliefs.3")
            ]
        case .death:
            return [
                String(localized: "interview.q.death.1"),
                String(localized: "interview.q.death.2"),
                String(localized: "interview.q.death.3")
            ]
        case .legacy:
            return [
                String(localized: "interview.q.legacy.1"),
                String(localized: "interview.q.legacy.2"),
                String(localized: "interview.q.legacy.3")
            ]
        }
    }
}

// MARK: - Interview Status

enum InterviewStatus: String, Codable {
    case inProgress
    case completed
    case skipped
}

// MARK: - Onboarding Questions

struct OnboardingQuestions {
    static let questions: [String] = [
        String(localized: "onboarding.q.name"),
        String(localized: "onboarding.q.call"),
        String(localized: "onboarding.q.location"),
        String(localized: "onboarding.q.important_person"),
        String(localized: "onboarding.q.three_words"),
        String(localized: "onboarding.q.thinking")
    ]
}
