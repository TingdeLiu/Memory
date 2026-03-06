# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Memory** is a native SwiftUI iOS app for recording memories, leaving messages to loved ones, and AI-powered memory organization. Targets iOS 17+ using SwiftData, CloudKit, CryptoKit, StoreKit 2, and Google Drive REST API. All 9 development phases complete (code-side). Remaining work: App icon, screenshots, TestFlight, App Store submission, Google Cloud Console setup (requires Mac).

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

Three `@Model` classes with a single relationship:
- **`MemoryEntry`** — Memories (text, audio, photo) with tags, mood, privacy flag
- **`Contact`** — People, with relationship type and optional system contact ID for dedup
- **`Message`** — Directed messages to contacts with delivery conditions

`Contact` → `Message` is one-to-many with cascade delete (`@Relationship(deleteRule: .cascade, inverse: \Message.contact)`).

The `ModelContainer` is configured in `MemoryApp.swift` and toggles between CloudKit (`.private("iCloud.com.tyndall.memory")`) and local-only (`.none`) based on the `iCloudSyncEnabled` AppStorage setting.

### Navigation — TabView with 5 tabs

`ContentView.swift` provides the root `TabView`:
- **Home** (`HomeView`) — Timeline with stats, date grouping ("Today"/"Yesterday"/weekday/full date), search, date range filter, AI quick access card
- **Memories** (`MemoryListView`) — Filterable list by type/mood/tag with sort options
- **Contacts** (`ContactListView`) — Grouped by relationship, favorites section, system contact import
- **AI** (`AIChatView`) — Chat with AI about memories, quick questions, multi-provider support
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
- **`StoreService`** — `@Observable` singleton (`StoreService.shared`), manages StoreKit 2 one-time purchase for Premium (`com.tyndall.memory.premium`). Loads products, handles purchase/restore, listens for transaction updates. Feature gating: `canUseAI`, `canCreateVoiceMemory`, `canCreateVideoMemory`, `canExportEncrypted`, `contactLimit` (free: 5), `voiceMemoryLimit` (free: 3), `videoMemoryLimit` (free: 1). Caches premium status in `@AppStorage("isPremiumCached")`.
- **`VideoRecordingService`** — `@Observable` video recording service. AVCaptureSession + AVCaptureMovieFileOutput. Front/back camera switching. Thumbnail generation via AVAssetImageGenerator. Auto-encrypts in full encryption mode.
- **`GoogleDriveSyncService`** — `@Observable` singleton (`GoogleDriveSyncService.shared`). Google Drive REST API v3 with OAuth 2.0 PKCE (ASWebAuthenticationSession). Tokens stored in Keychain (`com.tyndall.memory.gdrive`). Only accesses app-created files (drive.file scope). Encrypted sync via SyncDataSerializer.
- **`SyncDataSerializer`** — Serializes SwiftData models to/from JSON, encrypts/decrypts for cloud storage. SerializedMemory/Contact/Message structs. SyncManifest for incremental sync.

### Security Architecture

- **App lock**: `LockScreenView` gates `ContentView` when `requireBiometricAuth` is true. Auto-locks on scene phase → background.
- **Encryption**: `EncryptionHelper` uses AES-256-GCM (CryptoKit). Master key stored in Keychain under `com.tyndall.memory.encryption` service. Per-record keys derived via HKDF-SHA256. Two levels: `cloudOnly` (encrypt only for cloud) and `full` (encrypt sensitive fields locally + cloud). `EncryptedFieldHelper` provides per-record field-level encryption. Key backup/recovery via password-derived key.
- **Biometrics**: `BiometricAuth` wraps LocalAuthentication with Face ID → Touch ID → passcode fallback chain.
- **Secure delete**: `EncryptionHelper.secureDelete(at:)` overwrites file with random data before removal.

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
