# Memory for iOS

<p align="center">
  <strong>A privacy-first personal memory and legacy app.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**Memory** helps users preserve life's precious moments, record voice and video memories, and leave heartfelt messages for loved ones. Built with SwiftUI and designed with privacy at its core.

> *"You truly disappear only when no one in the world remembers you."*

## Features

### Core Functionality
- **Memory Journal** — Create rich text, voice, and video memories
- **Contact Management** — Associate memories with specific people
- **Legacy Messages** — Leave time-locked or condition-triggered messages
- **AI Assistant** — Intelligent memory organization powered by Claude, GPT, and Gemini

### Privacy & Security
- **Biometric Lock** — Face ID and Touch ID protection
- **AES-256-GCM Encryption** — Hardware-backed encryption via Secure Enclave
- **Local-First** — All data stored locally with iCloud sync opt-in
- **Data Export** — Full data portability

### Cloud & Sync
- **iCloud Sync** — Seamless sync across Apple devices
- **Google Drive** — Optional backup to Google Drive

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 5.9+

## Installation

1. Clone the repository
   ```bash
   git clone https://github.com/TingdeLiu/Memory.git
   cd Memory
   ```

2. Open `Memory_ios/Memory.xcodeproj` in Xcode

3. Configure signing with your Apple Developer account

4. Build and run (⌘R)

## Architecture

```
Memory/
├── App/              # App entry point and configuration
├── Models/           # Data models (SwiftData)
├── Views/            # SwiftUI views
├── Services/         # Business logic services
├── Utilities/        # Helper utilities
└── Resources/        # Assets and localization
```

### Tech Stack

| Category | Technology |
|----------|------------|
| UI | SwiftUI |
| Data | SwiftData |
| Cloud | CloudKit + Google Drive |
| Security | CryptoKit + Secure Enclave |
| Payments | StoreKit 2 |
| Speech | Speech Framework |

## Project Status

| Phase | Status |
|-------|--------|
| Core Features | Complete |
| Privacy & Security | Complete |
| AI Integration | Complete |
| Cloud Sync | Complete |
| StoreKit | Complete |
| App Store | Pending |

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with care by <a href="https://tyndall.dev">Tyndall Labs</a>
</p>
