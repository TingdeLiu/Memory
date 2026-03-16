import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @AppStorage("autoLockOnBackground") private var autoLockOnBackground = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @AppStorage("googleDriveEnabled") private var googleDriveEnabled = false

    @ObservedObject private var cloudService = CloudSyncService.shared
    private var gdriveService: GoogleDriveSyncService { GoogleDriveSyncService.shared }
    private var store: StoreService { StoreService.shared }
    private var languageManager: LanguageManager { LanguageManager.shared }
    @State private var showingPurchase = false
    @State private var showingFeedback = false
    @State private var showingLanguageRestart = false
    @State private var storageSize: String = "Calculating..."
    @State private var stats: DataStatistics?

    private var biometricType: BiometricAuth.BiometricType {
        BiometricAuth.availableType
    }

    var body: some View {
        NavigationStack {
            List {
                // Security
                securitySection

                // Premium
                premiumSection

                // iCloud & Sync
                syncSection

                // Privacy & Data
                dataSection

                // Language
                languageSection

                // Storage info
                storageSection

                // About
                aboutSection

                // Footer
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        Text("Memory")
                            .font(.headline)
                        Text(String(localized: "settings.tagline"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
            .task {
                await cloudService.checkiCloudStatus()
                await loadStats()
                calculateStorage()
            }
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        Section {
            if store.isPremium {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.premium.title"))
                        Text(String(localized: "settings.premium.unlocked"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Button {
                    showingPurchase = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.premium.upgrade"))
                            Text(String(localized: "settings.premium.upgradeSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.section.premium"))
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section {
            Toggle(isOn: $requireBiometricAuth) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "security.require") + " " + biometricType.displayName)
                        Text(String(localized: "security.lockOnClose"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: biometricType.systemImage)
                }
            }

            if requireBiometricAuth {
                Toggle(isOn: $autoLockOnBackground) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "security.autoLock"))
                            Text(String(localized: "security.autoLockSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.rotation")
                    }
                }
            }

            NavigationLink(destination: SecuritySettingsView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "security.encryption"))
                        Text(String(localized: "security.encryptionSubtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                }
            }
        } header: {
            Text(String(localized: "settings.section.security"))
        } footer: {
            if !BiometricAuth.isBiometricAvailable {
                Text(String(localized: "security.noBiometric"))
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        Section {
            // iCloud
            Toggle(isOn: $iCloudSyncEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.icloud"))
                        Text(String(localized: "settings.icloudSubtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "icloud.fill")
                }
            }

            if iCloudSyncEnabled {
                HStack {
                    Label(String(localized: "settings.syncStatus"), systemImage: cloudService.syncStatus.icon)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cloudService.syncStatus.color)
                            .frame(width: 8, height: 8)
                        Text(cloudService.syncStatus.label)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                if let lastSync = cloudService.lastSyncDate {
                    HStack {
                        Text(String(localized: "settings.lastSynced"))
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }

            // Google Drive
            NavigationLink(destination: GoogleDriveSettingsView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Drive")
                        Text(gdriveService.isSignedIn ? String(localized: "settings.gdrive.connected") : String(localized: "settings.gdrive.backup"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(gdriveService.isSignedIn ? .green : .secondary)
                }
            }
        } header: {
            Text(String(localized: "settings.section.sync"))
        } footer: {
            Text(String(localized: "settings.syncFooter"))
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section(String(localized: "settings.section.data")) {
            NavigationLink(destination: PrivacySettingsView()) {
                Label(String(localized: "settings.privacy"), systemImage: "hand.raised.fill")
            }

            NavigationLink(destination: AISettingsView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.aiSettings"))
                        Text(String(localized: "settings.aiSettingsSubtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(selection: Binding(
                get: { languageManager.currentLanguage },
                set: { newValue in
                    let oldValue = languageManager.currentLanguage
                    languageManager.currentLanguage = newValue
                    if oldValue != newValue {
                        showingLanguageRestart = true
                    }
                }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.language"))
                        Text(languageManager.currentLanguage.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "globe")
                }
            }
        } header: {
            Text(String(localized: "settings.section.language"))
        } footer: {
            Text(String(localized: "settings.language.footer"))
        }
        .alert(String(localized: "settings.language.restart.title"), isPresented: $showingLanguageRestart) {
            Button(String(localized: "common.ok")) { }
        } message: {
            Text(String(localized: "settings.language.restart.message"))
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section(String(localized: "settings.section.storage")) {
            HStack {
                Label(String(localized: "settings.localStorage"), systemImage: "internaldrive")
                Spacer()
                Text(storageSize)
                    .foregroundStyle(.secondary)
            }

            if let stats {
                HStack {
                    Text(String(localized: "settings.storage.memories"))
                    Spacer()
                    Text("\(stats.totalMemories)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack {
                    Text(String(localized: "settings.storage.contacts"))
                    Spacer()
                    Text("\(stats.totalContacts)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack {
                    Text(String(localized: "settings.storage.messages"))
                    Spacer()
                    Text("\(stats.totalMessages)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                if stats.sealedMessages > 0 {
                    HStack {
                        Label(String(localized: "settings.storage.sealed"), systemImage: "infinity")
                        Spacer()
                        Text("\(stats.sealedMessages)")
                            .foregroundStyle(.purple)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(String(localized: "settings.section.about")) {
            HStack {
                Text(String(localized: "settings.version"))
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            // Feedback Button
            Button {
                showingFeedback = true
            } label: {
                Label(String(localized: "settings.feedback"), systemImage: "bubble.left.and.text.bubble.right")
            }

            Link(destination: URL(string: "https://memory.app/privacy")!) {
                Label(String(localized: "settings.privacyPolicy"), systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://memory.app/terms")!) {
                Label(String(localized: "settings.termsOfUse"), systemImage: "doc.plaintext")
            }

            Link(destination: URL(string: "https://memory.app/support")!) {
                Label(String(localized: "settings.support"), systemImage: "questionmark.circle")
            }
        }
        .sheet(isPresented: $showingFeedback) {
            FeedbackView()
        }
    }

    // MARK: - Helpers

    private func calculateStorage() {
        Task.detached {
            let bytes = CloudSyncService.shared.calculateLocalStorageSize()
            let formatted = CloudSyncService.formatBytes(bytes)
            await MainActor.run {
                storageSize = formatted
            }
        }
    }

    private func loadStats() async {
        let container = modelContext.container
        let storage = StorageService(modelContainer: container)
        stats = try? await storage.getStatistics()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
