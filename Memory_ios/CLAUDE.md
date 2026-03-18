# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Memory** is a native SwiftUI iOS app for recording memories, leaving messages to loved ones, and AI-powered memory organization. Targets iOS 17+ using SwiftData, CloudKit, CryptoKit, StoreKit 2, and Google Drive REST API. All 11 development phases complete (code-side). Remaining work: App icon, screenshots, TestFlight, App Store submission, Google Cloud Console setup (requires Mac).

**Core Philosophy**: Not only AI needs memory — humans do too. Preserve memories to achieve digital immortality. The AI learns from your memories to truly understand you.

**Core concept**: "When no one in the world remembers you, that's when you truly disappear." The app helps users record memories, thoughts, and messages for specific people, with delivery conditions including "after I'm gone."

## Building & Running

### iOS App (requires macOS + Xcode 15+)

The project was authored on Windows without Xcode. To build:
1. Create a new SwiftUI App project in Xcode (iOS 17+, CloudKit enabled)
2. Drag the `Memory/` source folder into the Xcode project
3. Set Bundle ID to `com.tyndall.memory`
4. Add `Memory.entitlements` to the target
5. Build with `Cmd+R` on iPhone simulator

There is no working `.xcodeproj` — the `project.pbxproj` is a skeleton. Create a fresh Xcode project and import sources.

### Tests (iOS)

Tests use Swift Testing framework (`@Test`, `#expect`), not XCTest. Located in `MemoryTests/MemoryTests.swift`. Run via Xcode's test navigator or `Cmd+U`.

## iOS App Architecture

### Data Layer — SwiftData Models

Thirteen `@Model` classes:
- **`MemoryEntry`** — Memories (text, audio, photo, video) with tags, mood, privacy flag
- **`Contact`** — People, with relationship type and optional system contact ID for dedup
- **`Message`** — Directed messages to contacts with delivery conditions
- **`SoulProfile`** — User's personality profile (MBTI, Big Five, values, love languages, AI-generated insights)
- **`InterviewSession`** — Conversation records from AI-guided interviews
- **`AssessmentResult`** — Results from personality/values tests
- **`RelationshipProfile`** — AI-generated profile for each important relationship
- **`VoiceProfile`** — Voice clone configuration: provider (ElevenLabs/OpenAI/custom), status (notStarted/collecting/training/ready/failed), voiceId, sample count, total duration, quality metrics
- **`VoiceSample`** — Individual voice recording: audio file path, duration, transcription, prompt text, quality (pending/excellent/good/fair/poor), source type (recorded/memory/message)
- **`WritingStyleProfile`** — Writing style analysis: status, word/phrase frequencies (JSON), sentence/paragraph metrics, AI-generated style descriptions (style, tone, vocabulary, emotional, unique traits), sample texts
- **`AvatarProfile`** — User avatar: original photo (Data), stylized versions (JSON dictionary), selected style/frame, stylization status, timestamps
- **`DigitalSelfConfig`** — Digital presence configuration: status, component readiness flags, allowed contacts, access mode, personality mode, voice output toggle, emotional response level, conversation history (JSON), statistics
- **`TimeCapsule`** — Time capsule: unlock type (date/location/event), unlock date, location coordinates/radius/name, event description/target date, isUnlocked status, relationship to MemoryEntry

`MemoryEntry` → `TimeCapsule` is optional one-to-one. `Contact` → `Message` is one-to-many with cascade delete (`@Relationship(deleteRule: .cascade, inverse: \Message.contact)`).

The `ModelContainer` is configured in `MemoryApp.swift` and toggles between CloudKit (`.private("iCloud.com.tyndall.memory")`) and local-only (`.none`) based on the `iCloudSyncEnabled` AppStorage setting.

### Navigation — TabView with 6 tabs

`ContentView.swift` provides the root `TabView`:
- **Home** (`HomeView`) — Timeline with stats, date grouping ("Today"/"Yesterday"/weekday/full date), search, date range filter, AI quick access card
- **Memories** (`MemoryListView`) — Filterable list by type/mood/tag with sort options
- **Contacts** (`ContactListView`) — Grouped by relationship, favorites section, system contact import
- **AI** (`AIChatView`) — Chat with AI about memories, quick questions, multi-provider support
- **Soul** (`SoulTabView`) — User profile, personality assessments (MBTI, Big Five, values, love language), AI interviews
- **Settings** (`SettingsView`) — Security, Premium, iCloud, privacy, storage stats, AI settings

### Onboarding Flow

`OnboardingView` is shown on first launch (before lock screen). 3-page `TabView` with `.page` style. Sets `hasCompletedOnboarding` AppStorage to `true` on completion. Flow: `MemoryApp` → `OnboardingView` → `LockScreenView` → `ContentView`.

### View → Editor Pattern

Most features follow: ListView → DetailView → EditorView (sheet). Editors handle both create and edit via an optional `existingXxx` parameter:
```swift
struct MemoryEditorView: View {
    var existingMemory: MemoryEntry?  // nil = create, non-nil = edit
}
```

### ViewModels Layer (MVVM)

Complex views use dedicated ViewModels for better separation of concerns and testability:
- **`AIChatViewModel`** — Manages AI chat state, message history, and context memory fetching. Uses `FetchDescriptor` with `#Predicate` for efficient database queries instead of in-memory filtering.

### Services Layer

Services are `@Observable` or `ObservableObject` classes, instantiated as `@State` in views:
- **`AudioRecordingService`** — AVAudioRecorder with metering, stores files in `Documents/Recordings/`
- **`AudioPlaybackService`** — AVAudioPlayer with seek/progress
- **`SpeechTranscriptionService`** — Apple Speech framework, file-based and live transcription
- **`ContactImportService`** — CNContactStore wrapper with permission management and dedup filtering
- **`CloudSyncService`** — Singleton (`CloudSyncService.shared`), monitors CKAccountChanged notifications
- **`StorageService`** — Actor for data export (JSON/plain text) and statistics
- **`DataExportService`** — Coordinates export to temporary files for sharing
- **`AIService`** — `@Observable` multi-provider AI service. Supports Claude, OpenAI, Gemini, DeepSeek, and custom OpenAI-compatible endpoints. API keys stored per-provider in Keychain (`com.tyndall.memory.ai` service). Provides `summarizeMemories`, `chatAboutMemories`, `analyzeEmotionTrends`, `generateAnnualReport`. Privacy filtering excludes `isPrivate` memories and binary data. Crisis keyword detection appends hotline info.
- **`StoreService`** — `@Observable` singleton (`StoreService.shared`), manages StoreKit 2 one-time purchase for Premium (`com.tyndall.memory.premium`). Loads products, handles purchase/restore, listens for transaction updates. Feature gating: `canUseAI`, `canExportEncrypted`, `canUseDigitalSelf` (Premium only); `canCreateVoiceMemory`, `canCreateVideoMemory`, `contactLimit`, `voiceMemoryLimit`, `videoMemoryLimit` (all free unlimited). Caches premium status in `@AppStorage("isPremiumCached")`.
- **`VideoRecordingService`** — `@Observable` video recording service. AVCaptureSession + AVCaptureMovieFileOutput. Front/back camera switching. Thumbnail generation via AVAssetImageGenerator. Auto-encrypts in full encryption mode.
- **`GoogleDriveSyncService`** — `@Observable` singleton (`GoogleDriveSyncService.shared`). Google Drive REST API v3 with OAuth 2.0 PKCE (ASWebAuthenticationSession). Tokens stored in Keychain (`com.tyndall.memory.gdrive`). Only accesses app-created files (drive.file scope). Encrypted sync via SyncDataSerializer.
- **`SyncDataSerializer`** — Serializes SwiftData models to/from JSON, encrypts/decrypts for cloud storage. SerializedMemory/Contact/Message structs. SyncManifest for incremental sync.
- **`SoulService`** — `@Observable` singleton (`SoulService.shared`). Manages soul profile creation, memory analysis, assessment processing, interview insights generation. Uses AI to generate personality insights, life story, emotional patterns, core memories.
- **`InterviewService`** — `@Observable` service for conducting AI-guided interviews. Manages question flow, answer collection, AI follow-up generation, session completion with insights.
- **`VoiceCloneService`** — `@Observable` singleton (`VoiceCloneService.shared`). Multi-provider voice cloning: ElevenLabs (full clone), OpenAI TTS (preset voices), custom endpoints. API keys stored in Keychain (`com.tyndall.memory.voice`). Recording with quality evaluation (volume, noise, clarity). Training uploads samples to provider. Synthesis returns audio URLs.
- **`WritingStyleService`** — `@Observable` singleton (`WritingStyleService.shared`). Analyzes user's writing style from memories: word/phrase frequencies, sentence metrics, AI-generated style descriptions. Generates text in user's style for freeform prompts or occasion-based message drafts.
- **`AvatarService`** — `@Observable` singleton (`AvatarService.shared`). Image processing for avatar stylization: Core Image filters (CIColorPosterize, CIPhotoEffectNoir, CIComicEffect, etc.) as placeholders for AI stylization. Export with frame shapes (circle, square, hexagon). Image resize/crop utilities.
- **`DigitalSelfService`** — `@Observable` singleton (`DigitalSelfService.shared`). Integrates SoulProfile, WritingStyleProfile, VoiceProfile for conversation generation. Builds personalized system prompts, generates AI responses in user's style, synthesizes voice output, manages conversation context.
- **`FeedbackService`** — `@Observable` singleton (`FeedbackService.shared`). Collects user feedback with type classification, device info, and contact email. Stores locally as JSON in `Documents/Feedback/`, supports email composition via MFMailComposeViewController.
- **`TimeCapsuleService`** — `@Observable` singleton (`TimeCapsuleService.shared`). Manages time capsule lifecycle: date-based auto-unlock via UNUserNotificationCenter, location-based geofencing via CLLocationManager (CLCircularRegion, max 20 regions), event-based manual unlock. Countdown formatting helpers. On startup, checks date unlocks and re-registers geofences for location capsules.
- **`WidgetDataManager`** — Enum with static methods. Syncs SwiftData to App Group shared UserDefaults (`group.com.tyndall.memory`) for WidgetKit. Writes recent memories, stats, and capsule data as JSON. Read methods delegate to shared `WidgetDataReader`. Called from `MemoryApp` on background transition. Respects encryption level (full mode shows placeholder content).

### Widget Extension (Phase 19)

`MemoryWidgets` target — WidgetKit extension with App Groups:
- **`RecentMemoryWidget`** — Displays recent memories, rotates every 2 hours, supports all 6 widget families (systemSmall/Medium/Large, accessoryCircular/Rectangular/Inline)
- **`StatsWidget`** — Shows total memories, weekly count, top mood, streak. Supports small/medium + lock screen
- **`CapsuleCountdownWidget`** — Countdown to next capsule unlock, hourly refresh. Supports small/medium + lock screen
- **Shared Data** — `Shared/WidgetData.swift` compiled into both targets: `AppGroupConfig`, `WidgetMemory`, `WidgetStats`, `WidgetCapsule` (Codable), `WidgetDataReader`

### Light Orb Universe (Phase 16)

`LightOrbUniverseView` — Immersive 3D-style interface accessed by tapping the avatar in Soul tab:
- **Central Orb** — User's avatar with glowing effect, tap to pause/resume rotation
- **Satellite Orbs** — Contact avatars orbiting around, color-coded by relationship type, max 8 displayed
- **Animation** — Continuous rotation at 60fps using Timer.publish, with pulse effects on orbs
- **Chat** — `OrbChatView` opens when tapping a contact orb, AI role-plays as that person based on relationship and notes
- **Visual Effects** — Deep space gradient background, star field (Canvas), radial gradients for glow effects, `.ultraThinMaterial` for UI overlays

### Security Architecture

- **App lock**: `LockScreenView` gates `ContentView` when `requireBiometricAuth` is true. Auto-locks on scene phase → background.
- **Encryption**: `EncryptionHelper` uses AES-256-GCM (CryptoKit). Master key stored in Keychain under `com.tyndall.memory.encryption` service. Per-record keys derived via HKDF-SHA256. Two levels: `cloudOnly` (encrypt only for cloud) and `full` (encrypt sensitive fields locally + cloud). `EncryptedFieldHelper` provides per-record field-level encryption. Key backup/recovery via password-derived key.
- **Biometrics**: `BiometricAuth` wraps LocalAuthentication with Face ID → Touch ID → passcode fallback chain.
- **Secure delete**: `EncryptionHelper.secureDelete(at:)` overwrites file with random data before removal.

### Performance Optimizations

**Encryption caching** (avoids main thread blocking in full encryption mode):
- **Master key caching**: `EncryptionHelper.cachedMasterKey` stores the master key in memory after first Keychain read. Cleared on app lock via `clearCachedMasterKey()`.
- **Decryption result caching**: `MemoryEntry`, `Contact`, `Message` models use `@Transient` cached properties (`_cachedTitle`, `_cachedContent`, etc.) to avoid repeated decryption during list scrolling.
- **Async large data loading**: `loadPhotoDataAsync()`, `loadVideoThumbnailAsync()`, `loadAvatarDataAsync()` methods for non-blocking decryption of large binary fields.

**Database query optimization**:
- `AIChatViewModel.fetchContextMemories()` uses `FetchDescriptor` with `#Predicate` and `fetchLimit` instead of loading all memories and filtering in-memory.

### Key Enums

| Enum | Values | Used In |
|------|--------|---------|
| `MemoryType` | `.text`, `.audio`, `.photo`, `.video` | `MemoryEntry.type` |
| `EncryptionLevel` | `.cloudOnly`, `.full` | AppStorage `"encryptionLevel"` |
| `Mood` | 8 values with `.emoji` and `.label` | `MemoryEntry.mood` |
| `Relationship` | `.family`, `.partner`, `.friend`, `.colleague`, `.mentor`, `.other` | `Contact.relationship` |
| `DeliveryCondition` | `.immediate`, `.specificDate`, `.afterDeath` | `Message.deliveryCondition` |
| `MessageType` | `.text`, `.audio` | `Message.type` |
| `AIProvider` | `.claude`, `.openAI`, `.gemini`, `.deepSeek`, `.custom` | `AIService.selectedProvider` |
| `MBTIType` | 16 types (INTJ, INFJ, etc.) with `.description`, `.nickname` | `SoulProfile.mbtiType` |
| `LoveLanguage` | `.wordsOfAffirmation`, `.actsOfService`, `.receivingGifts`, `.qualityTime`, `.physicalTouch` | `SoulProfile.loveLanguages` |
| `CoreValue` | 15 values (family, health, freedom, etc.) | `SoulProfile.valuesRanking` |
| `InterviewType` | `.onboarding`, `.periodic`, `.milestone`, `.deepDive`, `.relationship` | `InterviewSession.type` |
| `InterviewTopic` | 12 topics (childhood, family, dreams, fears, etc.) | `InterviewSession.topic` |
| `AssessmentType` | `.mbti`, `.bigFive`, `.loveLanguage`, `.values` | `AssessmentResult.type` |
| `VoiceCloneStatus` | `.notStarted`, `.collecting`, `.training`, `.ready`, `.failed` | `VoiceProfile.status` |
| `VoiceCloneProvider` | `.elevenLabs`, `.openAITTS`, `.custom` | `VoiceProfile.provider` |
| `VoiceSampleQuality` | `.pending`, `.excellent`, `.good`, `.fair`, `.poor` | `VoiceSample.quality` |
| `VoiceSampleSource` | `.recorded`, `.memory`, `.message` | `VoiceSample.sourceType` |
| `WritingStyleStatus` | `.notAnalyzed`, `.analyzing`, `.ready`, `.failed` | `WritingStyleProfile.status` |
| `WritingOccasion` | `.birthday`, `.holiday`, `.gratitude`, `.apology`, `.encouragement`, `.farewell`, `.congratulations`, `.comfort`, `.love`, `.custom` | Message draft generation |
| `AvatarStyle` | `.natural`, `.artistic`, `.cartoon`, `.anime`, `.sketch`, `.oilPainting` | `AvatarProfile.selectedStyle` |
| `AvatarFrameStyle` | `.none`, `.circle`, `.square`, `.hexagon` | `AvatarProfile.selectedFrame` |
| `AvatarStylizationStatus` | `.notStarted`, `.processing`, `.ready`, `.failed` | `AvatarProfile.stylizationStatus` |
| `DigitalSelfStatus` | `.notReady`, `.ready`, `.active`, `.paused` | `DigitalSelfConfig.status` |
| `DigitalSelfAccessMode` | `.everyone`, `.selectedContacts`, `.noOne` | `DigitalSelfConfig.accessMode` |
| `DigitalSelfPersonalityMode` | `.authentic`, `.supportive`, `.playful`, `.wise` | `DigitalSelfConfig.personalityMode` |
| `CapsuleUnlockType` | `.date`, `.location`, `.event` | `TimeCapsule.unlockType` |

### Shared UI Components

- **`FlowLayout`** — Custom `Layout` for wrapping tag chips (defined in `MemoryEditorView.swift`)
- **`FilterChip`** — Reusable filter pill button (defined in `MemoryListView.swift`)
- **`ContactAvatarView`** — Relationship-colored circle with initial or photo (defined in `ContactListView.swift`)
- **`StatCard`** — Compact stat display card (defined in `HomeView.swift`)
- **`ShareSheet`** — UIActivityViewController wrapper (defined in `PrivacySettingsView.swift`)
- **`WaveformView`/`WaveformBar`** — Audio level visualization (defined in `MemoryEditorView.swift`)
- **`VoiceRecordingSheet`** — Reusable voice recording modal (defined in `MemoryEditorView.swift`, used by `MessageEditorView.swift`)

### Audio & Video File Convention

Audio files are stored as `memory_{UUID}.m4a` and video files as `memory_{UUID}.mov` in `Documents/Recordings/`. Models store only the filename (`audioFilePath`, `videoFilePath`), not the full path. Use `AudioRecordingService.recordingURL(for:)` to resolve the full URL. In full encryption mode, files are encrypted at rest and decrypted to temp for playback.

## Development Phases

| Phase | Status | Scope |
|-------|--------|-------|
| 1 | ✅ Done | Project structure, SwiftData models, TabView navigation |
| 2 | ✅ Done | Memory editor, voice recording, speech transcription, photo, auto-save, timeline |
| 3 | ✅ Done | Contact import, contact editor, message editor with voice, delivery conditions, message detail |
| 4 | ✅ Done | AES-256 encryption, Keychain, biometric lock, iCloud sync toggle, data export, secure delete |
| 5 | ✅ Done | Multi-provider AI (Claude/OpenAI/Gemini/DeepSeek/Custom), memory summarization, chat, insights |
| 6 | ✅ Done | StoreKit 2 IAP, purchase UI, onboarding, feature gating, accessibility, haptic feedback |
| 7 | ✅ Done | Encryption enhancement: cloudOnly/full levels, field-level encryption, key backup/recovery, migration |
| 8 | ✅ Done | Video memories: recording, import, playback, thumbnails, full-screen, Premium gating |
| 9 | ✅ Done | Google Drive sync: OAuth 2.0 PKCE, REST API v3, SyncDataSerializer, encrypted cloud backup |
| 10 | ✅ Done | Xcode project setup: xcodegen, project.yml, PrivacyInfo.xcprivacy, ModelContainer fix |
| 11 | ✅ Done | Soul Profile system: interviews, personality tests (MBTI/Big Five/values/love language), AI-generated insights, relationship profiles |
| 12 | ✅ Done | Voice Clone: ElevenLabs/OpenAI TTS/custom endpoint integration, voice sample recording with quality evaluation, training workflow, voice synthesis |
| 13 | ✅ Done | Writing Style: analyze writing from memories (word/phrase frequencies, metrics), AI-generated style profile, generate text in user's style (freeform + occasion-based drafts) |
| 14 | ✅ Done | Avatar: photo upload, 6 stylization filters (natural/artistic/cartoon/anime/sketch/oil painting), 4 frame shapes (none/circle/square/hexagon), Core Image processing, export with ShareSheet |
| 15 | ✅ Done | Digital Self: complete digital presence integrating Soul Profile + Voice Clone + Writing Style + Avatar, conversation interface with personality modes, access control, voice output support (Premium feature) |
| 16 | ✅ Done | Light Orb Universe: immersive 3D-style UI with central user orb and orbiting contact orbs, rotation animation with tap-to-pause, tap contact orbs to chat with AI role-playing as that person |
| 17 | ✅ Done | User Feedback: feedback form with type selection (bug/suggestion/feature/question/praise), device info collection, local storage + email fallback, full i18n support |
| 18 | ✅ Done | Time Capsule: seal memories with date/location/event unlock conditions, countdown UI, geofencing (CLCircularRegion), local notifications, 3-step creation flow, MapKit location picker |
| 19 | ✅ Done | Widgets: WidgetKit extension with App Groups, 3 widget types (RecentMemory/Stats/CapsuleCountdown), Home screen (small/medium/large) + Lock screen (circular/rectangular/inline), encryption-aware, auto-sync on background |

## AppStorage Keys

These `@AppStorage` keys are used across the app — keep them consistent:
- `"requireBiometricAuth"` — Bool, gates app lock
- `"autoLockOnBackground"` — Bool, locks when entering background
- `"iCloudSyncEnabled"` — Bool, toggles CloudKit in ModelContainer
- `"encryptAudioFiles"` — Bool, audio file encryption (Phase 4)
- `"aiEnabled"` — Bool, enables AI features (Phase 5)
- `"aiProvider"` — String (AIProvider rawValue), selected AI provider (Phase 5)
- `"aiModel"` — String, selected model for current provider (Phase 5)
- `"aiCustomBaseURL"` — String, custom OpenAI-compatible endpoint URL (Phase 5)
- `"aiCustomModel"` — String, custom endpoint model name (Phase 5)
- `"aiAllowPrivateMemories"` — Bool, allow AI access to private memories (Phase 5, default false)
- `"hasCompletedOnboarding"` — Bool, tracks first-launch onboarding completion (Phase 6)
- `"isPremiumCached"` — Bool, caches StoreKit premium status to avoid cold-start flicker (Phase 6)
- `"encryptionLevel"` — String (EncryptionLevel rawValue), `"cloudOnly"` or `"full"` (Phase 7, default: cloudOnly)
- `"googleDriveEnabled"` — Bool, toggles Google Drive sync (Phase 9)
- `"googleDriveLastSync"` — Double (TimeInterval), last Google Drive sync timestamp (Phase 9)

### Keychain Services

- `com.tyndall.memory.encryption` — Master encryption key
- `com.tyndall.memory.ai` — AI provider API keys
- `com.tyndall.memory.gdrive` — Google Drive OAuth tokens
- `com.tyndall.memory.voice` — Voice clone provider API keys (Phase 12)
