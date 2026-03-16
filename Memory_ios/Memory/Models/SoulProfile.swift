import Foundation
import SwiftData
import SwiftUI

@Model
final class SoulProfile {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Basic Info

    var _plainNickname: String?
    var _plainBirthday: Date?
    var _plainBirthplace: String?
    var _plainCurrentCity: String?

    var _encryptedNickname: String?
    var _encryptedBirthplace: String?
    var _encryptedCurrentCity: String?

    // MARK: - Assessment Results

    var mbtiType: String?
    var mbtiDate: Date?
    var bigFiveScores: Data?  // JSON: {"O": 0.8, "C": 0.6, "E": 0.4, "A": 0.7, "N": 0.3}
    var bigFiveDate: Date?
    var loveLanguages: [String]  // ["quality_time", "words_of_affirmation"]
    var loveLanguageDate: Date?
    var valuesRanking: [String]  // ["family", "health", "freedom", "achievement"]
    var schwartzValuesScores: Data? // JSON: {"power": 0.5, "achievement": 0.7, ...}
    var valuesDate: Date?
    var suggestedReflection: String? // AI suggested daily question

    // MARK: - AI Generated Insights (Markdown)

    var _plainPersonalityInsights: String?
    var _plainValuesAndBeliefs: String?
    var _plainLifeStory: String?
    var _plainCommunicationStyle: String?
    var _plainEmotionalPatterns: String?
    var _plainCoreMemoeries: String?

    var _encryptedPersonalityInsights: String?
    var _encryptedValuesAndBeliefs: String?
    var _encryptedLifeStory: String?
    var _encryptedCommunicationStyle: String?
    var _encryptedEmotionalPatterns: String?
    var _encryptedCoreMemories: String?

    // MARK: - Progress Tracking

    var interviewCount: Int
    var assessmentCount: Int
    var lastInterviewDate: Date?
    var lastMemoryAnalysisDate: Date?
    var profileCompleteness: Double  // 0.0 - 1.0

    // MARK: - Transparent Accessors

    var nickname: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedNickname {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainNickname
        }
        set {
            _plainNickname = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedNickname = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedNickname = nil
            }
        }
    }

    var birthday: Date? {
        get { _plainBirthday }
        set { _plainBirthday = newValue }
    }

    var birthplace: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedBirthplace {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainBirthplace
        }
        set {
            _plainBirthplace = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedBirthplace = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedBirthplace = nil
            }
        }
    }

    var currentCity: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedCurrentCity {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainCurrentCity
        }
        set {
            _plainCurrentCity = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedCurrentCity = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedCurrentCity = nil
            }
        }
    }

    var personalityInsights: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedPersonalityInsights {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainPersonalityInsights
        }
        set {
            _plainPersonalityInsights = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedPersonalityInsights = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedPersonalityInsights = nil
            }
        }
    }

    var valuesAndBeliefs: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedValuesAndBeliefs {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainValuesAndBeliefs
        }
        set {
            _plainValuesAndBeliefs = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedValuesAndBeliefs = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedValuesAndBeliefs = nil
            }
        }
    }

    var lifeStory: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedLifeStory {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainLifeStory
        }
        set {
            _plainLifeStory = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedLifeStory = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedLifeStory = nil
            }
        }
    }

    var communicationStyle: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedCommunicationStyle {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainCommunicationStyle
        }
        set {
            _plainCommunicationStyle = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedCommunicationStyle = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedCommunicationStyle = nil
            }
        }
    }

    var emotionalPatterns: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedEmotionalPatterns {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainEmotionalPatterns
        }
        set {
            _plainEmotionalPatterns = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedEmotionalPatterns = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedEmotionalPatterns = nil
            }
        }
    }

    var coreMemories: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedCoreMemories {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainCoreMemoeries
        }
        set {
            _plainCoreMemoeries = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedCoreMemories = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedCoreMemories = nil
            }
        }
    }

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self._plainNickname = nil
        self._plainBirthday = nil
        self._plainBirthplace = nil
        self._plainCurrentCity = nil
        self._encryptedNickname = nil
        self._encryptedBirthplace = nil
        self._encryptedCurrentCity = nil
        self.mbtiType = nil
        self.mbtiDate = nil
        self.bigFiveScores = nil
        self.bigFiveDate = nil
        self.loveLanguages = []
        self.loveLanguageDate = nil
        self.valuesRanking = []
        self.schwartzValuesScores = nil
        self.valuesDate = nil
        self._plainPersonalityInsights = nil
        self._plainValuesAndBeliefs = nil
        self._plainLifeStory = nil
        self._plainCommunicationStyle = nil
        self._plainEmotionalPatterns = nil
        self._plainCoreMemoeries = nil
        self._encryptedPersonalityInsights = nil
        self._encryptedValuesAndBeliefs = nil
        self._encryptedLifeStory = nil
        self._encryptedCommunicationStyle = nil
        self._encryptedEmotionalPatterns = nil
        self._encryptedCoreMemories = nil
        self.interviewCount = 0
        self.assessmentCount = 0
        self.lastInterviewDate = nil
        self.lastMemoryAnalysisDate = nil
        self.profileCompleteness = 0.0
    }

    // MARK: - Computed Properties

    var displayName: String {
        nickname ?? String(localized: "soul.unnamed")
    }

    var mbtiDescription: String? {
        guard let mbti = mbtiType else { return nil }
        return MBTIType(rawValue: mbti)?.description
    }

    var age: Int? {
        guard let birthday = birthday else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthday, to: Date())
        return components.year
    }

    func calculateCompleteness() -> Double {
        var score = 0.0
        let weights: [(Bool, Double)] = [
            (nickname != nil, 0.1),
            (birthday != nil, 0.05),
            (birthplace != nil, 0.05),
            (mbtiType != nil, 0.15),
            (!loveLanguages.isEmpty, 0.1),
            (!valuesRanking.isEmpty, 0.1),
            (personalityInsights != nil, 0.15),
            (lifeStory != nil, 0.15),
            (interviewCount >= 3, 0.15)
        ]
        for (condition, weight) in weights {
            if condition { score += weight }
        }
        return min(score, 1.0)
    }

    func updateCompleteness() {
        profileCompleteness = calculateCompleteness()
        updatedAt = Date()
    }

    enum SoulLevel {
        case spark // 0-25%
        case star // 26-50%
        case constellation // 51-75%
        case galaxy // 76-100%

        var title: String {
            switch self {
            case .spark: return String(localized: "level.spark")
            case .star: return String(localized: "level.star")
            case .constellation: return String(localized: "level.constellation")
            case .galaxy: return String(localized: "level.galaxy")
            }
        }
        
        var icon: String {
            switch self {
            case .spark: return "sparkles"
            case .star: return "star.fill"
            case .constellation: return "circle.grid.cross.fill"
            case .galaxy: return "hurricane"
            }
        }
    }

    var currentLevel: SoulLevel {
        if profileCompleteness < 0.25 { return .spark }
        if profileCompleteness < 0.50 { return .star }
        if profileCompleteness < 0.75 { return .constellation }
        return .galaxy
    }

    // MARK: - Migration Helpers

    func encryptAllFields() {
        if let n = _plainNickname {
            _encryptedNickname = EncryptedFieldHelper.encryptString(n, recordId: id)
        }
        if let b = _plainBirthplace {
            _encryptedBirthplace = EncryptedFieldHelper.encryptString(b, recordId: id)
        }
        if let c = _plainCurrentCity {
            _encryptedCurrentCity = EncryptedFieldHelper.encryptString(c, recordId: id)
        }
        if let p = _plainPersonalityInsights {
            _encryptedPersonalityInsights = EncryptedFieldHelper.encryptString(p, recordId: id)
        }
        if let v = _plainValuesAndBeliefs {
            _encryptedValuesAndBeliefs = EncryptedFieldHelper.encryptString(v, recordId: id)
        }
        if let l = _plainLifeStory {
            _encryptedLifeStory = EncryptedFieldHelper.encryptString(l, recordId: id)
        }
        if let c = _plainCommunicationStyle {
            _encryptedCommunicationStyle = EncryptedFieldHelper.encryptString(c, recordId: id)
        }
        if let e = _plainEmotionalPatterns {
            _encryptedEmotionalPatterns = EncryptedFieldHelper.encryptString(e, recordId: id)
        }
        if let m = _plainCoreMemoeries {
            _encryptedCoreMemories = EncryptedFieldHelper.encryptString(m, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let e = _encryptedNickname, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainNickname = d
        }
        if let e = _encryptedBirthplace, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainBirthplace = d
        }
        if let e = _encryptedCurrentCity, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainCurrentCity = d
        }
        if let e = _encryptedPersonalityInsights, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainPersonalityInsights = d
        }
        if let e = _encryptedValuesAndBeliefs, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainValuesAndBeliefs = d
        }
        if let e = _encryptedLifeStory, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainLifeStory = d
        }
        if let e = _encryptedCommunicationStyle, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainCommunicationStyle = d
        }
        if let e = _encryptedEmotionalPatterns, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainEmotionalPatterns = d
        }
        if let e = _encryptedCoreMemories, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainCoreMemoeries = d
        }

        _encryptedNickname = nil
        _encryptedBirthplace = nil
        _encryptedCurrentCity = nil
        _encryptedPersonalityInsights = nil
        _encryptedValuesAndBeliefs = nil
        _encryptedLifeStory = nil
        _encryptedCommunicationStyle = nil
        _encryptedEmotionalPatterns = nil
        _encryptedCoreMemories = nil
    }

    // MARK: - UI Themes

    struct UniverseTheme {
        let colors: [Color]
        let starColor: Color
    }

    func getUniverseTheme() -> UniverseTheme {
        // Simple logic for now, can be expanded to check actual recent memory moods
        return UniverseTheme(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.05, blue: 0.2), Color(red: 0.05, green: 0.02, blue: 0.1)],
            starColor: .white
        )
    }
}

// MARK: - MBTI Type

enum MBTIType: String, CaseIterable, Codable {
    case INTJ, INTP, ENTJ, ENTP
    case INFJ, INFP, ENFJ, ENFP
    case ISTJ, ISFJ, ESTJ, ESFJ
    case ISTP, ISFP, ESTP, ESFP

    var description: String {
        switch self {
        case .INTJ: return String(localized: "mbti.intj")
        case .INTP: return String(localized: "mbti.intp")
        case .ENTJ: return String(localized: "mbti.entj")
        case .ENTP: return String(localized: "mbti.entp")
        case .INFJ: return String(localized: "mbti.infj")
        case .INFP: return String(localized: "mbti.infp")
        case .ENFJ: return String(localized: "mbti.enfj")
        case .ENFP: return String(localized: "mbti.enfp")
        case .ISTJ: return String(localized: "mbti.istj")
        case .ISFJ: return String(localized: "mbti.isfj")
        case .ESTJ: return String(localized: "mbti.estj")
        case .ESFJ: return String(localized: "mbti.esfj")
        case .ISTP: return String(localized: "mbti.istp")
        case .ISFP: return String(localized: "mbti.isfp")
        case .ESTP: return String(localized: "mbti.estp")
        case .ESFP: return String(localized: "mbti.esfp")
        }
    }

    var nickname: String {
        switch self {
        case .INTJ: return String(localized: "mbti.intj.nickname")
        case .INTP: return String(localized: "mbti.intp.nickname")
        case .ENTJ: return String(localized: "mbti.entj.nickname")
        case .ENTP: return String(localized: "mbti.entp.nickname")
        case .INFJ: return String(localized: "mbti.infj.nickname")
        case .INFP: return String(localized: "mbti.infp.nickname")
        case .ENFJ: return String(localized: "mbti.enfj.nickname")
        case .ENFP: return String(localized: "mbti.enfp.nickname")
        case .ISTJ: return String(localized: "mbti.istj.nickname")
        case .ISFJ: return String(localized: "mbti.isfj.nickname")
        case .ESTJ: return String(localized: "mbti.estj.nickname")
        case .ESFJ: return String(localized: "mbti.esfj.nickname")
        case .ISTP: return String(localized: "mbti.istp.nickname")
        case .ISFP: return String(localized: "mbti.isfp.nickname")
        case .ESTP: return String(localized: "mbti.estp.nickname")
        case .ESFP: return String(localized: "mbti.esfp.nickname")
        }
    }

    // Dimension breakdown
    var isIntrovert: Bool { rawValue.hasPrefix("I") }
    var isIntuitive: Bool { rawValue.contains("N") }
    var isThinking: Bool { rawValue.contains("T") }
    var isJudging: Bool { rawValue.hasSuffix("J") }
}

// MARK: - Big Five Scores

struct BigFiveScores: Codable {
    var openness: Double        // O - Openness to experience
    var conscientiousness: Double // C - Conscientiousness
    var extraversion: Double    // E - Extraversion
    var agreeableness: Double   // A - Agreeableness
    var neuroticism: Double     // N - Neuroticism

    init(O: Double = 0.5, C: Double = 0.5, E: Double = 0.5, A: Double = 0.5, N: Double = 0.5) {
        self.openness = O
        self.conscientiousness = C
        self.extraversion = E
        self.agreeableness = A
        self.neuroticism = N
    }
}

// MARK: - Love Language

enum LoveLanguage: String, CaseIterable, Codable {
    case wordsOfAffirmation = "words_of_affirmation"
    case actsOfService = "acts_of_service"
    case receivingGifts = "receiving_gifts"
    case qualityTime = "quality_time"
    case physicalTouch = "physical_touch"

    var label: String {
        switch self {
        case .wordsOfAffirmation: return String(localized: "love_language.words")
        case .actsOfService: return String(localized: "love_language.acts")
        case .receivingGifts: return String(localized: "love_language.gifts")
        case .qualityTime: return String(localized: "love_language.time")
        case .physicalTouch: return String(localized: "love_language.touch")
        }
    }

    var icon: String {
        switch self {
        case .wordsOfAffirmation: return "text.bubble.fill"
        case .actsOfService: return "hands.sparkles.fill"
        case .receivingGifts: return "gift.fill"
        case .qualityTime: return "clock.fill"
        case .physicalTouch: return "hand.raised.fill"
        }
    }
}

// MARK: - Core Values

enum CoreValue: String, CaseIterable, Codable {
    case family
    case health
    case freedom
    case achievement
    case creativity
    case security
    case adventure
    case love
    case wisdom
    case wealth
    case friendship
    case spirituality
    case justice
    case beauty
    case knowledge

    var label: String {
        switch self {
        case .family: return String(localized: "value.family")
        case .health: return String(localized: "value.health")
        case .freedom: return String(localized: "value.freedom")
        case .achievement: return String(localized: "value.achievement")
        case .creativity: return String(localized: "value.creativity")
        case .security: return String(localized: "value.security")
        case .adventure: return String(localized: "value.adventure")
        case .love: return String(localized: "value.love")
        case .wisdom: return String(localized: "value.wisdom")
        case .wealth: return String(localized: "value.wealth")
        case .friendship: return String(localized: "value.friendship")
        case .spirituality: return String(localized: "value.spirituality")
        case .justice: return String(localized: "value.justice")
        case .beauty: return String(localized: "value.beauty")
        case .knowledge: return String(localized: "value.knowledge")
        }
    }

    var icon: String {
        switch self {
        case .family: return "house.fill"
        case .health: return "heart.fill"
        case .freedom: return "bird.fill"
        case .achievement: return "trophy.fill"
        case .creativity: return "paintbrush.fill"
        case .security: return "shield.fill"
        case .adventure: return "mountain.2.fill"
        case .love: return "heart.circle.fill"
        case .wisdom: return "brain.head.profile"
        case .wealth: return "dollarsign.circle.fill"
        case .friendship: return "person.2.fill"
        case .spirituality: return "sparkles"
        case .justice: return "scale.3d"
        case .beauty: return "leaf.fill"
        case .knowledge: return "book.fill"
        }
    }
}

// MARK: - Schwartz Values Scores

struct SchwartzValuesScores: Codable {
    var power: Double
    var achievement: Double
    var hedonism: Double
    var stimulation: Double
    var selfDirection: Double
    var universalism: Double
    var benevolence: Double
    var tradition: Double
    var conformity: Double
    var security: Double

    init(power: Double = 0.5, achievement: Double = 0.5, hedonism: Double = 0.5,
         stimulation: Double = 0.5, selfDirection: Double = 0.5, universalism: Double = 0.5,
         benevolence: Double = 0.5, tradition: Double = 0.5, conformity: Double = 0.5,
         security: Double = 0.5) {
        self.power = power
        self.achievement = achievement
        self.hedonism = hedonism
        self.stimulation = stimulation
        self.selfDirection = selfDirection
        self.universalism = universalism
        self.benevolence = benevolence
        self.tradition = tradition
        self.conformity = conformity
        self.security = security
    }

    var sortedDimensions: [(String, Double)] {
        return [
            (String(localized: "value.schwartz.power"), power),
            (String(localized: "value.schwartz.achievement"), achievement),
            (String(localized: "value.schwartz.hedonism"), hedonism),
            (String(localized: "value.schwartz.stimulation"), stimulation),
            (String(localized: "value.schwartz.self_direction"), selfDirection),
            (String(localized: "value.schwartz.universalism"), universalism),
            (String(localized: "value.schwartz.benevolence"), benevolence),
            (String(localized: "value.schwartz.tradition"), tradition),
            (String(localized: "value.schwartz.conformity"), conformity),
            (String(localized: "value.schwartz.security"), security)
        ].sorted { $0.1 > $1.1 }
    }
}
