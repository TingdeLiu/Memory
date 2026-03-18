import Foundation
import SwiftData

@Model
final class MemoryEntry {
    var id: UUID
    var type: MemoryType
    var mood: Mood?
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date
    var audioDuration: TimeInterval?
    var videoFilePath: String?
    var videoDuration: TimeInterval?
    var unlockDate: Date?

    // MARK: - Time Capsule Relationship (Phase 20)
    var timeCapsule: TimeCapsule?

    // MARK: - Plain-text storage (always used in cloudOnly mode)

    var _plainTitle: String
    var _plainContent: String
    var _plainTags: [String]
    var _plainTranscription: String?
    var _plainPhotoData: Data?
    var _plainAudioFilePath: String?
    var _plainVideoThumbnailData: Data?

    // MARK: - Encrypted storage (used in full encryption mode)

    var _encryptedTitle: String?
    var _encryptedContent: String?
    var _encryptedTags: String?
    var _encryptedTranscription: String?
    var _encryptedPhotoData: Data?
    var _encryptedAudioFilePath: String?
    var _encryptedVideoThumbnailData: Data?

    // MARK: - Decryption Cache (Performance Optimization)
    // These caches avoid repeated decryption during list scrolling.
    // Note: @Transient prevents SwiftData from persisting these fields.

    @Transient private var _cachedTitle: String?
    @Transient private var _cachedContent: String?
    @Transient private var _cachedTags: [String]?
    @Transient private var _cachedTranscription: String?
    @Transient private var _cachedAudioFilePath: String?

    /// Invalidate all decryption caches (call when encryption level changes).
    func invalidateDecryptionCache() {
        _cachedTitle = nil
        _cachedContent = nil
        _cachedTags = nil
        _cachedTranscription = nil
        _cachedAudioFilePath = nil
    }

    // MARK: - Transparent accessors

    var title: String {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedTitle {
                if let cached = _cachedTitle { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) ?? _plainTitle
                _cachedTitle = decrypted
                return decrypted
            }
            return _plainTitle
        }
        set {
            _plainTitle = newValue
            _cachedTitle = newValue
            if EncryptionLevel.current == .full {
                _encryptedTitle = EncryptedFieldHelper.encryptString(newValue, recordId: id)
            }
        }
    }

    var content: String {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedContent {
                if let cached = _cachedContent { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) ?? _plainContent
                _cachedContent = decrypted
                return decrypted
            }
            return _plainContent
        }
        set {
            _plainContent = newValue
            _cachedContent = newValue
            if EncryptionLevel.current == .full {
                _encryptedContent = EncryptedFieldHelper.encryptString(newValue, recordId: id)
            }
        }
    }

    var tags: [String] {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedTags {
                if let cached = _cachedTags { return cached }
                let decrypted = EncryptedFieldHelper.decryptStringArray(encrypted, recordId: id) ?? _plainTags
                _cachedTags = decrypted
                return decrypted
            }
            return _plainTags
        }
        set {
            _plainTags = newValue
            _cachedTags = newValue
            if EncryptionLevel.current == .full {
                _encryptedTags = EncryptedFieldHelper.encryptStringArray(newValue, recordId: id)
            }
        }
    }

    var transcription: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedTranscription {
                if let cached = _cachedTranscription { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id)
                _cachedTranscription = decrypted
                return decrypted
            }
            return _plainTranscription
        }
        set {
            _plainTranscription = newValue
            _cachedTranscription = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedTranscription = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedTranscription = nil
            }
        }
    }

    // MARK: - Large Data Fields (No sync cache - use async loading)
    // photoData and videoThumbnailData are large and should be loaded asynchronously.
    // Use loadPhotoDataAsync() and loadVideoThumbnailAsync() in views.

    var photoData: Data? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedPhotoData {
                return EncryptedFieldHelper.decryptData(encrypted, recordId: id)
            }
            return _plainPhotoData
        }
        set {
            _plainPhotoData = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedPhotoData = EncryptedFieldHelper.encryptData(value, recordId: id)
            } else {
                _encryptedPhotoData = nil
            }
        }
    }

    var audioFilePath: String? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedAudioFilePath {
                if let cached = _cachedAudioFilePath { return cached }
                let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id)
                _cachedAudioFilePath = decrypted
                return decrypted
            }
            return _plainAudioFilePath
        }
        set {
            _plainAudioFilePath = newValue
            _cachedAudioFilePath = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedAudioFilePath = EncryptedFieldHelper.encryptString(value, recordId: id)
            } else {
                _encryptedAudioFilePath = nil
            }
        }
    }

    var videoThumbnailData: Data? {
        get {
            if EncryptionLevel.current == .full, let encrypted = _encryptedVideoThumbnailData {
                return EncryptedFieldHelper.decryptData(encrypted, recordId: id)
            }
            return _plainVideoThumbnailData
        }
        set {
            _plainVideoThumbnailData = newValue
            if EncryptionLevel.current == .full, let value = newValue {
                _encryptedVideoThumbnailData = EncryptedFieldHelper.encryptData(value, recordId: id)
            } else {
                _encryptedVideoThumbnailData = nil
            }
        }
    }

    // MARK: - Async Data Loading (for large binary fields)

    /// Load photo data asynchronously to avoid blocking the main thread.
    func loadPhotoDataAsync() async -> Data? {
        let entry = self
        return await withCheckedContinuation { continuation in
            Task.detached {
                let data = entry.photoData
                continuation.resume(returning: data)
            }
        }
    }

    /// Load video thumbnail asynchronously to avoid blocking the main thread.
    func loadVideoThumbnailAsync() async -> Data? {
        let entry = self
        return await withCheckedContinuation { continuation in
            Task.detached {
                let data = entry.videoThumbnailData
                continuation.resume(returning: data)
            }
        }
    }

    var isLocked: Bool {
        if let capsule = timeCapsule {
            return !capsule.isUnlocked
        }
        if let unlockDate = unlockDate {
            return Date() < unlockDate
        }
        return false
    }

    init(
        title: String = "",

        content: String = "",
        type: MemoryType = .text,
        tags: [String] = [],
        mood: Mood? = nil,
        isPrivate: Bool = false,
        audioFilePath: String? = nil,
        audioDuration: TimeInterval? = nil,
        transcription: String? = nil,
        photoData: Data? = nil,
        videoFilePath: String? = nil,
        videoDuration: TimeInterval? = nil,
        videoThumbnailData: Data? = nil,
        unlockDate: Date? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.mood = mood
        self.isPrivate = isPrivate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.audioDuration = audioDuration
        self.videoFilePath = videoFilePath
        self.videoDuration = videoDuration
        self.unlockDate = unlockDate

        // Store plain values
        self._plainTitle = title
        self._plainContent = content
        self._plainTags = tags
        self._plainTranscription = transcription
        self._plainPhotoData = photoData
        self._plainAudioFilePath = audioFilePath
        self._plainVideoThumbnailData = videoThumbnailData

        // Initialize encrypted fields
        self._encryptedTitle = nil
        self._encryptedContent = nil
        self._encryptedTags = nil
        self._encryptedTranscription = nil
        self._encryptedPhotoData = nil
        self._encryptedAudioFilePath = nil
        self._encryptedVideoThumbnailData = nil

        // If full encryption mode, also encrypt
        if EncryptionLevel.current == .full {
            self._encryptedTitle = EncryptedFieldHelper.encryptString(title, recordId: self.id)
            self._encryptedContent = EncryptedFieldHelper.encryptString(content, recordId: self.id)
            self._encryptedTags = EncryptedFieldHelper.encryptStringArray(tags, recordId: self.id)
            if let transcription {
                self._encryptedTranscription = EncryptedFieldHelper.encryptString(transcription, recordId: self.id)
            }
            if let photoData {
                self._encryptedPhotoData = EncryptedFieldHelper.encryptData(photoData, recordId: self.id)
            }
            if let audioFilePath {
                self._encryptedAudioFilePath = EncryptedFieldHelper.encryptString(audioFilePath, recordId: self.id)
            }
            if let videoThumbnailData {
                self._encryptedVideoThumbnailData = EncryptedFieldHelper.encryptData(videoThumbnailData, recordId: self.id)
            }
        }
    }

    // MARK: - Migration helpers

    /// Encrypt all plain fields for switching to full encryption mode.
    func encryptAllFields() {
        _encryptedTitle = EncryptedFieldHelper.encryptString(_plainTitle, recordId: id)
        _encryptedContent = EncryptedFieldHelper.encryptString(_plainContent, recordId: id)
        _encryptedTags = EncryptedFieldHelper.encryptStringArray(_plainTags, recordId: id)
        if let t = _plainTranscription {
            _encryptedTranscription = EncryptedFieldHelper.encryptString(t, recordId: id)
        }
        if let p = _plainPhotoData {
            _encryptedPhotoData = EncryptedFieldHelper.encryptData(p, recordId: id)
        }
        if let a = _plainAudioFilePath {
            _encryptedAudioFilePath = EncryptedFieldHelper.encryptString(a, recordId: id)
        }
        if let v = _plainVideoThumbnailData {
            _encryptedVideoThumbnailData = EncryptedFieldHelper.encryptData(v, recordId: id)
        }
    }

    /// Clear all encrypted fields when switching to cloudOnly mode.
    func clearEncryptedFields() {
        // First, ensure plain fields have the decrypted values
        if let encrypted = _encryptedTitle, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainTitle = decrypted
        }
        if let encrypted = _encryptedContent, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainContent = decrypted
        }
        if let encrypted = _encryptedTags, let decrypted = EncryptedFieldHelper.decryptStringArray(encrypted, recordId: id) {
            _plainTags = decrypted
        }
        if let encrypted = _encryptedTranscription, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainTranscription = decrypted
        }
        if let encrypted = _encryptedPhotoData, let decrypted = EncryptedFieldHelper.decryptData(encrypted, recordId: id) {
            _plainPhotoData = decrypted
        }
        if let encrypted = _encryptedAudioFilePath, let decrypted = EncryptedFieldHelper.decryptString(encrypted, recordId: id) {
            _plainAudioFilePath = decrypted
        }
        if let encrypted = _encryptedVideoThumbnailData, let decrypted = EncryptedFieldHelper.decryptData(encrypted, recordId: id) {
            _plainVideoThumbnailData = decrypted
        }

        _encryptedTitle = nil
        _encryptedContent = nil
        _encryptedTags = nil
        _encryptedTranscription = nil
        _encryptedPhotoData = nil
        _encryptedAudioFilePath = nil
        _encryptedVideoThumbnailData = nil
    }
}

enum MemoryType: String, Codable, CaseIterable {
    case text
    case audio
    case photo
    case video
}

enum Mood: String, Codable, CaseIterable {
    case happy
    case grateful
    case calm
    case nostalgic
    case sad
    case anxious
    case hopeful
    case loving

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .grateful: return "🙏"
        case .calm: return "😌"
        case .nostalgic: return "🥹"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .hopeful: return "🌟"
        case .loving: return "❤️"
        }
    }

    var label: String {
        switch self {
        case .happy: return String(localized: "mood.happy")
        case .grateful: return String(localized: "mood.grateful")
        case .calm: return String(localized: "mood.calm")
        case .nostalgic: return String(localized: "mood.nostalgic")
        case .sad: return String(localized: "mood.sad")
        case .anxious: return String(localized: "mood.anxious")
        case .hopeful: return String(localized: "mood.hopeful")
        case .loving: return String(localized: "mood.loving")
        }
    }
}
