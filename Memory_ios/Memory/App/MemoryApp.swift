import SwiftUI
import SwiftData

@main
struct MemoryApp: App {
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @AppStorage("autoLockOnBackground") private var autoLockOnBackground = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    private var languageManager: LanguageManager { LanguageManager.shared }

    // ModelContainer created once at app launch
    // Note: iCloud setting is read at launch; changes require app restart
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MemoryEntry.self,
            Contact.self,
            Message.self,
            SoulProfile.self,
            InterviewSession.self,
            AssessmentResult.self,
            RelationshipProfile.self,
            VoiceProfile.self,
            VoiceSample.self,
            WritingStyleProfile.self,
            AvatarProfile.self,
            DigitalSelfConfig.self,
        ])

        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let cloudKitDB: ModelConfiguration.CloudKitDatabase = iCloudEnabled
            ? .private("iCloud.com.tyndall.memory")
            : .none

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDB
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else if requireBiometricAuth && !isUnlocked {
                    LockScreenView(isUnlocked: $isUnlocked)
                } else {
                    ContentView()
                }
            }
            .environment(\.locale, languageManager.effectiveLocale)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if requireBiometricAuth && autoLockOnBackground {
                    isUnlocked = false
                    // Clear cached encryption key when app locks for security
                    EncryptionHelper.clearCachedMasterKey()
                }
            case .active:
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
