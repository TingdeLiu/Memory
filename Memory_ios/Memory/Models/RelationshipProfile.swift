import Foundation
import SwiftData

@Model
final class RelationshipProfile {
    var id: UUID
    var contact: Contact?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationship Details

    var howWeMet: String?
    var firstMemoryDate: Date?
    var importantDates: Data?  // JSON: [{"date": "2020-01-01", "label": "First met"}]

    // MARK: - AI Generated Content

    var _plainSharedMemoriesSummary: String?
    var _plainRelationshipDynamics: String?
    var _plainThingsILove: String?
    var _plainUnspokenWords: String?
    var _plainOurStory: String?

    var _encryptedSharedMemoriesSummary: String?
    var _encryptedRelationshipDynamics: String?
    var _encryptedThingsILove: String?
    var _encryptedUnspokenWords: String?
    var _encryptedOurStory: String?

    // MARK: - Tracking

    var interviewCount: Int
    var lastInterviewDate: Date?
    var lastAnalysisDate: Date?
    var profileCompleteness: Double

    // MARK: - Transparent Accessors

    var sharedMemoriesSummary: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedSharedMemoriesSummary {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainSharedMemoriesSummary
        }
        set {
            _plainSharedMemoriesSummary = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedSharedMemoriesSummary = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedSharedMemoriesSummary = nil
            }
        }
    }

    var relationshipDynamics: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedRelationshipDynamics {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainRelationshipDynamics
        }
        set {
            _plainRelationshipDynamics = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedRelationshipDynamics = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedRelationshipDynamics = nil
            }
        }
    }

    var thingsILove: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedThingsILove {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainThingsILove
        }
        set {
            _plainThingsILove = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedThingsILove = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedThingsILove = nil
            }
        }
    }

    var unspokenWords: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedUnspokenWords {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainUnspokenWords
        }
        set {
            _plainUnspokenWords = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedUnspokenWords = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedUnspokenWords = nil
            }
        }
    }

    var ourStory: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedOurStory {
                return EncryptedFieldHelper.decryptString(encrypted, recordId: id)
            }
            return _plainOurStory
        }
        set {
            _plainOurStory = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedOurStory = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedOurStory = nil
            }
        }
    }

    init(contact: Contact) {
        self.id = UUID()
        self.contact = contact
        self.createdAt = Date()
        self.updatedAt = Date()
        self.howWeMet = nil
        self.firstMemoryDate = nil
        self.importantDates = nil
        self._plainSharedMemoriesSummary = nil
        self._plainRelationshipDynamics = nil
        self._plainThingsILove = nil
        self._plainUnspokenWords = nil
        self._plainOurStory = nil
        self._encryptedSharedMemoriesSummary = nil
        self._encryptedRelationshipDynamics = nil
        self._encryptedThingsILove = nil
        self._encryptedUnspokenWords = nil
        self._encryptedOurStory = nil
        self.interviewCount = 0
        self.lastInterviewDate = nil
        self.lastAnalysisDate = nil
        self.profileCompleteness = 0.0
    }

    // MARK: - Computed Properties

    var contactName: String {
        contact?.name ?? String(localized: "relationship.unknown")
    }

    var relationshipType: Relationship {
        contact?.relationship ?? .other
    }

    var relationshipDuration: DateComponents? {
        guard let firstDate = firstMemoryDate else { return nil }
        return Calendar.current.dateComponents([.year, .month], from: firstDate, to: Date())
    }

    var durationDescription: String? {
        guard let duration = relationshipDuration else { return nil }
        if let years = duration.year, years > 0 {
            return String(localized: "relationship.duration.years \(years)")
        } else if let months = duration.month, months > 0 {
            return String(localized: "relationship.duration.months \(months)")
        }
        return nil
    }

    // MARK: - Important Dates

    struct ImportantDate: Codable {
        var date: Date
        var label: String
        var isRecurring: Bool  // Birthday, anniversary
    }

    var parsedImportantDates: [ImportantDate] {
        guard let data = importantDates else { return [] }
        return (try? JSONDecoder().decode([ImportantDate].self, from: data)) ?? []
    }

    func setImportantDates(_ dates: [ImportantDate]) {
        importantDates = try? JSONEncoder().encode(dates)
    }

    func addImportantDate(_ date: ImportantDate) {
        var dates = parsedImportantDates
        dates.append(date)
        setImportantDates(dates)
    }

    // MARK: - Completeness

    func calculateCompleteness() -> Double {
        var score = 0.0
        let weights: [(Bool, Double)] = [
            (howWeMet != nil, 0.15),
            (firstMemoryDate != nil, 0.1),
            (!parsedImportantDates.isEmpty, 0.1),
            (sharedMemoriesSummary != nil, 0.2),
            (relationshipDynamics != nil, 0.15),
            (thingsILove != nil, 0.15),
            (interviewCount >= 1, 0.15)
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

    // MARK: - Migration Helpers

    func encryptAllFields() {
        if let s = _plainSharedMemoriesSummary {
            _encryptedSharedMemoriesSummary = EncryptedFieldHelper.encryptString(s, recordId: id)
        }
        if let r = _plainRelationshipDynamics {
            _encryptedRelationshipDynamics = EncryptedFieldHelper.encryptString(r, recordId: id)
        }
        if let t = _plainThingsILove {
            _encryptedThingsILove = EncryptedFieldHelper.encryptString(t, recordId: id)
        }
        if let u = _plainUnspokenWords {
            _encryptedUnspokenWords = EncryptedFieldHelper.encryptString(u, recordId: id)
        }
        if let o = _plainOurStory {
            _encryptedOurStory = EncryptedFieldHelper.encryptString(o, recordId: id)
        }
    }

    func clearEncryptedFields() {
        if let e = _encryptedSharedMemoriesSummary, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainSharedMemoriesSummary = d
        }
        if let e = _encryptedRelationshipDynamics, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainRelationshipDynamics = d
        }
        if let e = _encryptedThingsILove, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainThingsILove = d
        }
        if let e = _encryptedUnspokenWords, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainUnspokenWords = d
        }
        if let e = _encryptedOurStory, let d = EncryptedFieldHelper.decryptString(e, recordId: id) {
            _plainOurStory = d
        }

        _encryptedSharedMemoriesSummary = nil
        _encryptedRelationshipDynamics = nil
        _encryptedThingsILove = nil
        _encryptedUnspokenWords = nil
        _encryptedOurStory = nil
    }
}

// MARK: - Relationship Interview Questions

struct RelationshipInterviewQuestions {
    static func questions(for relationship: Relationship, name: String) -> [String] {
        let common = [
            String(localized: "rel.q.how_met \(name)"),
            String(localized: "rel.q.first_impression \(name)"),
            String(localized: "rel.q.favorite_memory \(name)"),
            String(localized: "rel.q.admire \(name)"),
            String(localized: "rel.q.unsaid \(name)")
        ]

        let specific: [String]
        switch relationship {
        case .family:
            specific = [
                String(localized: "rel.q.family.childhood \(name)"),
                String(localized: "rel.q.family.tradition \(name)"),
                String(localized: "rel.q.family.learned \(name)")
            ]
        case .partner:
            specific = [
                String(localized: "rel.q.partner.fell_in_love \(name)"),
                String(localized: "rel.q.partner.special \(name)"),
                String(localized: "rel.q.partner.future \(name)")
            ]
        case .friend:
            specific = [
                String(localized: "rel.q.friend.bond \(name)"),
                String(localized: "rel.q.friend.through \(name)"),
                String(localized: "rel.q.friend.grateful \(name)")
            ]
        case .mentor:
            specific = [
                String(localized: "rel.q.mentor.impact \(name)"),
                String(localized: "rel.q.mentor.lesson \(name)"),
                String(localized: "rel.q.mentor.thanks \(name)")
            ]
        case .colleague, .other:
            specific = [
                String(localized: "rel.q.other.role \(name)"),
                String(localized: "rel.q.other.memorable \(name)")
            ]
        }

        return common + specific
    }
}
