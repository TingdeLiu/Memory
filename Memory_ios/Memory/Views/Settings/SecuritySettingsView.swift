import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @AppStorage("autoLockOnBackground") private var autoLockOnBackground = true
    @AppStorage("encryptAudioFiles") private var encryptAudioFiles = false
    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"

    @State private var masterKeyExists = false
    @State private var showingResetKeyAlert = false
    @State private var showingBackupSheet = false
    @State private var showingRestoreSheet = false
    @State private var showingMigrationAlert = false
    @State private var pendingLevel: EncryptionLevel?
    @State private var isMigrating = false
    @State private var migrationProgress: Double = 0
    @State private var migrationStatus = ""
    @State private var recoveryPassword = ""
    @State private var confirmRecoveryPassword = ""
    @State private var backupError: String?
    @State private var restorePassword = ""
    @State private var restoreError: String?
    @State private var hasRecoveryBackup = false

    private var encryptionLevel: EncryptionLevel {
        EncryptionLevel(rawValue: encryptionLevelRaw) ?? .cloudOnly
    }

    private var biometricType: BiometricAuth.BiometricType {
        BiometricAuth.availableType
    }

    var body: some View {
        List {
            // Biometric auth
            Section {
                Toggle(isOn: $requireBiometricAuth) {
                    Label(String(localized: "security.require") + " " + biometricType.displayName, systemImage: biometricType.systemImage)
                }

                if requireBiometricAuth {
                    Toggle(isOn: $autoLockOnBackground) {
                        Label(String(localized: "security.autoLock"), systemImage: "lock.rotation")
                    }
                }
            } header: {
                Text(String(localized: "security.appLock"))
            } footer: {
                Text(L10n.securityAppLockFooter(biometricType.displayName))
            }

            // Encryption level
            Section {
                ForEach(EncryptionLevel.allCases, id: \.self) { level in
                    Button {
                        if level != encryptionLevel {
                            pendingLevel = level
                            showingMigrationAlert = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .font(.title3)
                                .foregroundStyle(level == .full ? .orange : .blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(level.label)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    if level == .cloudOnly {
                                        Text(String(localized: "security.recommended"))
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if encryptionLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .disabled(isMigrating)
                }
            } header: {
                Text(String(localized: "security.encryptionLevel"))
            } footer: {
                if encryptionLevel == .full {
                    Text(String(localized: "security.fullFooter"))
                } else {
                    Text(String(localized: "security.cloudFooter"))
                }
            }

            // Migration progress
            if isMigrating {
                Section {
                    VStack(spacing: 8) {
                        ProgressView(value: migrationProgress)
                        Text(migrationStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "security.migration"))
                }
            }

            // Encryption details
            Section {
                HStack {
                    Label(String(localized: "security.algorithm"), systemImage: "lock.shield")
                    Spacer()
                    Text("AES-256-GCM")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack {
                    Label(String(localized: "security.keyStorage"), systemImage: "key")
                    Spacer()
                    Text(String(localized: "security.keyStorageValue"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack {
                    Label(String(localized: "security.masterKey"), systemImage: masterKeyExists ? "checkmark.shield.fill" : "shield.slash")
                    Spacer()
                    Text(masterKeyExists ? String(localized: "security.masterKey.active") : String(localized: "security.masterKey.notCreated"))
                        .foregroundStyle(masterKeyExists ? .green : .secondary)
                        .font(.subheadline)
                }

                if !masterKeyExists {
                    Button {
                        createMasterKey()
                    } label: {
                        Label(String(localized: "security.initKey"), systemImage: "key.fill")
                    }
                }
            } header: {
                Text(String(localized: "security.encryption"))
            } footer: {
                Text(String(localized: "security.encryptionFooter"))
            }

            // Key backup (full mode)
            if encryptionLevel == .full {
                Section {
                    Button {
                        showingBackupSheet = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "security.setRecovery"))
                                Text(String(localized: "security.setRecoverySubtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.viewfinder")
                        }
                    }

                    if hasRecoveryBackup {
                        HStack {
                            Label(String(localized: "security.recoveryBackup"), systemImage: "checkmark.shield.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(String(localized: "security.configured"))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Button {
                        showingRestoreSheet = true
                    } label: {
                        Label(String(localized: "security.restoreRecovery"), systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text(String(localized: "security.keyRecovery"))
                } footer: {
                    Text(String(localized: "security.keyRecoveryFooter"))
                }
            }

            // Audio encryption
            Section {
                Toggle(isOn: $encryptAudioFiles) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "security.encryptAudio"))
                            Text(String(localized: "security.encryptAudioSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "waveform.badge.magnifyingglass")
                    }
                }
            } footer: {
                Text(String(localized: "security.encryptAudioFooter"))
            }

            // iCloud encryption
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(String(localized: "security.e2e"), systemImage: "lock.icloud.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    EncryptionInfoRow(title: String(localized: "security.dataAtRest"), detail: String(localized: "security.dataAtRestDetail"), icon: "internaldrive.fill", color: .green)
                    EncryptionInfoRow(title: String(localized: "security.dataInTransit"), detail: String(localized: "security.dataInTransitDetail"), icon: "network", color: .blue)
                    EncryptionInfoRow(title: String(localized: "security.icloudStorage"), detail: String(localized: "security.icloudStorageDetail"), icon: "icloud.fill", color: .purple)
                    EncryptionInfoRow(title: String(localized: "security.keychain"), detail: String(localized: "security.keychainDetail"), icon: "cpu", color: .orange)
                }
            } header: {
                Text(String(localized: "security.dataProtection"))
            } footer: {
                Text(String(localized: "security.dataProtectionFooter"))
            }

            // Danger zone
            Section {
                Button(role: .destructive) {
                    showingResetKeyAlert = true
                } label: {
                    Label(String(localized: "security.resetKey"), systemImage: "exclamationmark.triangle")
                }
            } header: {
                Text(String(localized: "security.advanced"))
            } footer: {
                Text(String(localized: "security.resetKeyFooter"))
            }
        }
        .navigationTitle(String(localized: "security.title"))
        .alert(String(localized: "security.resetKeyTitle"), isPresented: $showingResetKeyAlert) {
            Button(String(localized: "security.resetButton"), role: .destructive) {
                EncryptionHelper.deleteMasterKey()
                masterKeyExists = false
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "security.resetKeyMessage"))
        }
        .alert(String(localized: "security.changeLevelTitle"), isPresented: $showingMigrationAlert) {
            Button(String(localized: "security.migrateButton"), role: .destructive) {
                if let level = pendingLevel {
                    Task { await performMigration(to: level) }
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                pendingLevel = nil
            }
        } message: {
            if let level = pendingLevel {
                if level == .full {
                    Text(String(localized: "security.migrateToFull"))
                } else {
                    Text(String(localized: "security.migrateToCloud"))
                }
            }
        }
        .sheet(isPresented: $showingBackupSheet) {
            backupSheet
        }
        .sheet(isPresented: $showingRestoreSheet) {
            restoreSheet
        }
        .onAppear {
            checkMasterKey()
            hasRecoveryBackup = EncryptionHelper.retrieveRecoveryBackup() != nil

            // Resume interrupted migration if needed
            if UserDefaults.standard.bool(forKey: "migrationInProgress"),
               let targetRaw = UserDefaults.standard.string(forKey: "migrationTargetLevel"),
               let target = EncryptionLevel(rawValue: targetRaw) {
                Task { await performMigration(to: target) }
            }
        }
    }

    // MARK: - Backup Sheet

    private var backupSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "security.recoveryPassword"), text: $recoveryPassword)
                    SecureField(String(localized: "security.confirmPassword"), text: $confirmRecoveryPassword)
                } footer: {
                    Text(String(localized: "security.recoveryPasswordFooter"))
                }

                if let error = backupError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(String(localized: "security.setRecovery"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        recoveryPassword = ""
                        confirmRecoveryPassword = ""
                        backupError = nil
                        showingBackupSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveRecoveryPassword()
                    }
                    .fontWeight(.semibold)
                    .disabled(recoveryPassword.count < 8 || recoveryPassword != confirmRecoveryPassword)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Restore Sheet

    private var restoreSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "security.recoveryPassword"), text: $restorePassword)
                } footer: {
                    Text(String(localized: "security.restoreFooter"))
                }

                if let error = restoreError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(String(localized: "security.restoreKey"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        restorePassword = ""
                        restoreError = nil
                        showingRestoreSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "security.restoreButton")) {
                        performRestore()
                    }
                    .fontWeight(.semibold)
                    .disabled(restorePassword.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func checkMasterKey() {
        masterKeyExists = (try? EncryptionHelper.retrieveKeyFromKeychain(forAccount: "master-encryption-key")) != nil
    }

    private func createMasterKey() {
        do {
            _ = try EncryptionHelper.masterKey()
            masterKeyExists = true
        } catch {
            // Key creation failed
        }
    }

    private func saveRecoveryPassword() {
        guard recoveryPassword == confirmRecoveryPassword else {
            backupError = "Passwords do not match."
            return
        }
        guard recoveryPassword.count >= 8 else {
            backupError = "Password must be at least 8 characters."
            return
        }

        do {
            let backup = try EncryptionHelper.backupMasterKey(withPassword: recoveryPassword)
            try EncryptionHelper.storeRecoveryBackup(backup)
            hasRecoveryBackup = true
            recoveryPassword = ""
            confirmRecoveryPassword = ""
            backupError = nil
            showingBackupSheet = false
        } catch {
            backupError = "Failed to create backup: \(error.localizedDescription)"
        }
    }

    private func performRestore() {
        guard let backup = EncryptionHelper.retrieveRecoveryBackup() else {
            restoreError = "No recovery backup found."
            return
        }

        do {
            try EncryptionHelper.restoreMasterKey(from: backup, withPassword: restorePassword)
            masterKeyExists = true
            restorePassword = ""
            restoreError = nil
            showingRestoreSheet = false
        } catch {
            restoreError = "Invalid recovery password."
        }
    }

    @MainActor
    private func performMigration(to newLevel: EncryptionLevel) async {
        isMigrating = true
        migrationProgress = 0

        // Persist migration state so we can resume if interrupted
        UserDefaults.standard.set(true, forKey: "migrationInProgress")
        UserDefaults.standard.set(newLevel.rawValue, forKey: "migrationTargetLevel")

        do {
            _ = try EncryptionHelper.masterKey()
        } catch {
            isMigrating = false
            UserDefaults.standard.removeObject(forKey: "migrationInProgress")
            return
        }

        let container = modelContext.container

        // Process in batches on a background-friendly context
        let batchSize = 50

        // Migrate memories
        migrationStatus = String(localized: "security.migrating.memories")
        do {
            let bgContext = ModelContext(container)
            let memories = (try? bgContext.fetch(FetchDescriptor<MemoryEntry>())) ?? []
            let total = memories.count
            for (index, memory) in memories.enumerated() {
                if newLevel == .full {
                    memory.encryptAllFields()
                } else {
                    memory.clearEncryptedFields()
                }
                // Save in batches to limit memory and enable partial recovery
                if (index + 1) % batchSize == 0 || index == total - 1 {
                    try? bgContext.save()
                }
                migrationProgress = Double(index + 1) / Double(max(1, total)) * 0.5
            }
        }

        // Migrate contacts
        migrationStatus = String(localized: "security.migrating.contacts")
        do {
            let bgContext = ModelContext(container)
            let contacts = (try? bgContext.fetch(FetchDescriptor<Contact>())) ?? []
            for (index, contact) in contacts.enumerated() {
                if newLevel == .full {
                    contact.encryptAllFields()
                } else {
                    contact.clearEncryptedFields()
                }
                if (index + 1) % batchSize == 0 || index == contacts.count - 1 {
                    try? bgContext.save()
                }
            }
        }
        migrationProgress = 0.7

        // Migrate messages
        migrationStatus = String(localized: "security.migrating.messages")
        do {
            let bgContext = ModelContext(container)
            let messages = (try? bgContext.fetch(FetchDescriptor<Message>())) ?? []
            for (index, message) in messages.enumerated() {
                if newLevel == .full {
                    message.encryptAllFields()
                } else {
                    message.clearEncryptedFields()
                }
                if (index + 1) % batchSize == 0 || index == messages.count - 1 {
                    try? bgContext.save()
                }
            }
        }
        migrationProgress = 0.9

        // Migrate audio/video files
        if newLevel == .full {
            migrationStatus = String(localized: "security.migrating.encrypting")
            encryptMediaFiles()
        } else {
            migrationStatus = String(localized: "security.migrating.decrypting")
            decryptMediaFiles()
        }

        migrationProgress = 1.0
        migrationStatus = "Complete"

        encryptionLevelRaw = newLevel.rawValue
        pendingLevel = nil

        // Clear migration state
        UserDefaults.standard.removeObject(forKey: "migrationInProgress")
        UserDefaults.standard.removeObject(forKey: "migrationTargetLevel")

        try? await Task.sleep(for: .seconds(1))
        isMigrating = false
    }

    private func encryptMediaFiles() {
        guard let key = try? EncryptionHelper.masterKey() else { return }
        let recordingsDir = AudioRecordingService.recordingsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? EncryptionHelper.encryptFile(at: file, using: key)
        }
    }

    private func decryptMediaFiles() {
        guard let key = try? EncryptionHelper.masterKey() else { return }
        let recordingsDir = AudioRecordingService.recordingsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? EncryptionHelper.decryptFile(at: file, using: key)
        }
    }
}

struct EncryptionInfoRow: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
