# Memory

<p align="center">
  <strong>When no one in the world remembers you, that's when you truly disappear.</strong>
</p>

<p align="center">
  A privacy-first, emotionally intelligent app for preserving life's moments and achieving digital immortality.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue?logo=apple" alt="iOS 17+"/>
  <img src="https://img.shields.io/badge/Android-API%2026%2B-green?logo=android" alt="Android API 26+"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift 5.9"/>
  <img src="https://img.shields.io/badge/Kotlin-1.9-purple?logo=kotlin" alt="Kotlin 1.9"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"/>
</p>

---

## What is Memory?

**Memory** isn't just another journal app. It's a platform for **digital legacy** — helping you record memories, leave messages for loved ones, and build an AI-powered digital self that truly understands you.

The AI learns from your memories, your writing style, your personality, and your voice to create a digital presence that captures who you are. Messages can be set to deliver on specific dates, at specific locations, or even after you're gone.

### Core Philosophy

- **Not only AI needs memory — humans do too.** Preserve memories to achieve digital immortality.
- **Privacy is non-negotiable.** All data encrypted locally with AES-256-GCM. Zero-knowledge architecture.
- **Your data, your control.** Local-first by default. Cloud sync is always opt-in.

---

## Platforms

| Platform | Directory | Status | Stack |
|----------|-----------|--------|-------|
| **iOS** | `Memory_ios/` | Phase 1-18 Complete | SwiftUI, SwiftData, CloudKit |
| **Android (China)** | `Memory_andriod_china/` | In Development | Jetpack Compose, Room, Aliyun OSS |
| **Android (Global)** | `Memory_andriod_world/` | In Development | Jetpack Compose, Room, Google Drive |

---

## Feature Overview

### Record & Preserve
- Rich text, voice, photo, and video memories
- Speech-to-text transcription
- Mood tracking with 8 emotional states
- Tag-based organization with timeline view
- Auto-save drafts

### People & Messages
- Contact management with relationship types
- Legacy messages with delivery conditions: **immediate**, **specific date**, or **after I'm gone**
- System contact import with dedup

### Time Capsules
- Seal memories for the future with three unlock modes:
  - **Date unlock** — Opens automatically on a chosen date
  - **Location unlock** — Opens when you arrive at a specific place (geofencing)
  - **Event unlock** — Opens when you decide the moment is right
- Live countdown timers
- Local notification on unlock

### AI Intelligence
- Multi-provider support: Claude, GPT, Gemini, DeepSeek, custom endpoints
- Memory summarization, emotional analysis, trend insights
- AI chat grounded in your personal memories
- Crisis keyword detection with hotline info

### Soul & Digital Self
- **Personality profiling** — MBTI, Big Five, Values, Love Language assessments
- **AI interviews** — Guided conversations to map your inner world
- **Voice cloning** — ElevenLabs, OpenAI TTS, or custom providers
- **Writing style analysis** — Word frequencies, sentence patterns, AI-generated style profile
- **Avatar stylization** — 6 filters (natural/artistic/cartoon/anime/sketch/oil painting)
- **Digital Self** — AI persona that combines all of the above to chat as you

### Light Orb Universe
- Immersive 3D-style interface with orbital animation
- Contact orbs orbit around your central avatar
- Tap any contact to chat with an AI role-playing as that person

### Security
- Biometric lock (Face ID / Touch ID / passcode fallback)
- AES-256-GCM field-level encryption via CryptoKit
- Two encryption levels: `cloudOnly` and `full`
- Secure delete (overwrite before removal)
- Encrypted cloud backup (iCloud + Google Drive)

### Monetization
- StoreKit 2 one-time Premium purchase
- Free: unlimited text/voice/photo memories, unlimited contacts
- Premium: AI features, Digital Self, encrypted export, video memories

---

## Getting Started

### iOS (requires macOS + Xcode 16+)

```bash
git clone https://github.com/TingdeLiu/Memory.git
cd Memory/Memory_ios
```

1. Open `Memory.xcodeproj` in Xcode (or regenerate via `xcodegen`)
2. Set Bundle ID to `com.tyndall.memory`
3. Configure signing with your Apple Developer account
4. Build and run (`Cmd+R`)

### Android (China Edition)

```bash
cd Memory/Memory_andriod_china
./gradlew assembleDebug
```

### Android (Global Edition)

```bash
cd Memory/Memory_andriod_world
./gradlew assembleDebug
```

---

## Architecture (iOS)

```
Memory_ios/Memory/
├── App/                # Entry point, ContentView, App Intents
├── Models/             # 13 SwiftData @Model classes
├── Services/           # 23 service classes (@Observable singletons)
├── Views/
│   ├── Home/           # Timeline, stats, capsule card
│   ├── Memory/         # List, detail, editor, reel
│   ├── Contacts/       # Contact & message management
│   ├── AI/             # Multi-provider AI chat
│   ├── Soul/           # Personality, interviews, voice, avatar, digital self
│   ├── TimeCapsule/    # Capsule list, detail, editor, countdown
│   ├── Voice/          # Voice clone training & settings
│   ├── Settings/       # Security, premium, sync, privacy, feedback
│   └── Onboarding/     # 3-page first-launch flow
├── ViewModels/         # MVVM view models
├── Utilities/          # Encryption, biometrics, i18n
└── Resources/          # Assets, en/zh-Hans/zh-Hant localization
```

### Tech Stack (iOS)

| Category | Technology |
|----------|------------|
| UI | SwiftUI (iOS 17+) |
| Architecture | MVVM + @Observable |
| Data | SwiftData + CloudKit |
| Security | CryptoKit (AES-256-GCM) + Keychain |
| AI | Multi-provider REST API |
| Payments | StoreKit 2 |
| Speech | Speech Framework |
| Maps | MapKit + CoreLocation |
| Notifications | UserNotifications |

---

## Development Progress

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Project structure, SwiftData models, TabView | Done |
| 2 | Memory editor, voice recording, speech-to-text, photos | Done |
| 3 | Contacts, messages, delivery conditions | Done |
| 4 | AES-256 encryption, Keychain, biometric lock, iCloud sync | Done |
| 5 | Multi-provider AI (Claude/GPT/Gemini/DeepSeek/Custom) | Done |
| 6 | StoreKit 2 IAP, onboarding, feature gating | Done |
| 7 | Field-level encryption, key backup/recovery, migration | Done |
| 8 | Video memories (record, import, playback, thumbnails) | Done |
| 9 | Google Drive sync (OAuth 2.0 PKCE, encrypted backup) | Done |
| 10 | Xcode project setup (xcodegen, PrivacyInfo) | Done |
| 11 | Soul Profile (AI interviews, MBTI/Big Five/Values/Love Language) | Done |
| 12 | Voice Clone (ElevenLabs/OpenAI TTS/Custom, quality eval) | Done |
| 13 | Writing Style (frequency analysis, AI style profile) | Done |
| 14 | Avatar (6 stylization filters, 4 frame shapes) | Done |
| 15 | Digital Self (integrated persona, conversation interface) | Done |
| 16 | Light Orb Universe (3D orbital UI, AI roleplay chat) | Done |
| 17 | User Feedback (form, device info, local storage, i18n) | Done |
| 18 | Time Capsule (date/location/event unlock, countdown, geofencing) | Done |

---

## TODO

### App Store Launch (Priority: Critical)
- [ ] Design and export App Icon (1024x1024)
- [ ] Create App Store screenshots (6.7", 6.5", 5.5")
- [ ] Write App Store description and keywords (en/zh)
- [ ] Configure App Store Connect listing
- [ ] Set up Google Cloud Console for Google Drive OAuth
- [ ] TestFlight internal testing
- [ ] TestFlight external beta (10+ testers)
- [ ] Submit for App Store review
- [ ] Prepare Privacy Policy and Terms of Service URLs

### Code Quality & Stability
- [ ] Refactor `MemoryListView` to MVVM (extract ViewModel)
- [ ] Refactor `ContactDetailView` to MVVM (extract ViewModel)
- [ ] Decouple `HomeView` business logic
- [ ] Add unit tests for `TimeCapsuleService` (date/location/event unlock)
- [ ] Add unit tests for `EncryptionHelper` (encrypt/decrypt round-trip)
- [ ] Add unit tests for `SyncDataSerializer` (serialization/deserialization)
- [ ] Add UI tests for critical flows (create memory, create capsule, onboarding)
- [ ] Audit accessibility labels across all views

### Phase 19: Widgets (Next)
- [ ] Create WidgetKit extension target
- [ ] "Memory of the Day" widget (random past memory, "on this day X years ago")
- [ ] Quick capture widget (deep link to editor)
- [ ] Weekly mood chart widget (small/medium sizes)
- [ ] Lock Screen widget (iOS 16+)
- [ ] Add localization strings for widgets

### Phase 20: Apple Watch App
- [ ] Create watchOS target (watchOS 10+)
- [ ] Quick voice memory recording (raise to record)
- [ ] Siri Shortcuts integration
- [ ] Complication: today's memory count + recent mood
- [ ] WatchConnectivity bidirectional sync with iPhone
- [ ] Haptic reminders to record daily thoughts

### Phase 21-29: Future Roadmap
- [ ] AR Spatial Memories (ARKit, LiDAR)
- [ ] Family Sharing (groups, permission levels, family tree)
- [ ] Mac Catalyst / native macOS app
- [ ] Digital Legacy (heir designation, inactivity protocols)
- [ ] Advanced AI Analytics (annual review, life chapters, relationship health)
- [ ] On-device AI (Core ML, Apple Intelligence)
- [ ] Rich Media (PencilKit sketches, Apple Music, map trails)
- [ ] Social Sharing (curated collections, E2E encrypted links)
- [ ] Enterprise Edition (caregiver mode, HIPAA compliance)

### Android Parity
- [ ] Feature parity audit: iOS vs Android China vs Android Global
- [ ] Cross-platform data format compatibility
- [ ] Time Capsule feature port to Android
- [ ] Digital Self feature port to Android

### Infrastructure
- [ ] Set up CI/CD (GitHub Actions for build/test)
- [ ] Configure Fastlane for automated App Store deployment
- [ ] Set up crash reporting (Firebase Crashlytics or similar)
- [ ] Performance profiling with Instruments (memory, CPU, battery)

---

## Localization

| Language | Status |
|----------|--------|
| English | Complete |
| Simplified Chinese (zh-Hans) | Complete |
| Traditional Chinese (zh-Hant) | Complete |
| Japanese | Planned |
| Korean | Planned |

---

## License

MIT License - see [LICENSE](LICENSE) for details.

Copyright (c) 2024-2026 [Tyndall Labs](https://tyndall.dev)
