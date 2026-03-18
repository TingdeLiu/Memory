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

    /// Set to true if the persistent store failed and we fell back to in-memory
    private static var isUsingFallbackContainer = false

    private static let appSchema = Schema([
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
        TimeCapsule.self,
    ])

    // ModelContainer created once at app launch
    // Note: iCloud setting is read at launch; changes require app restart
    let sharedModelContainer: ModelContainer = {
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let cloudKitDB: ModelConfiguration.CloudKitDatabase = iCloudEnabled
            ? .private("iCloud.com.tyndall.memory")
            : .none

        let modelConfiguration = ModelConfiguration(
            schema: appSchema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDB
        )

        do {
            return try ModelContainer(for: appSchema, configurations: [modelConfiguration])
        } catch {
            // Fallback to in-memory container to prevent crash
            isUsingFallbackContainer = true
            let fallbackConfig = ModelConfiguration(
                schema: appSchema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: appSchema, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.isUsingFallbackContainer {
                    DatabaseErrorView()
                } else if !hasCompletedOnboarding {
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
                    EncryptionHelper.clearCachedMasterKey()
                }
                // Sync data to widgets in background to avoid blocking main thread
                let container = sharedModelContainer
                Task.detached {
                    let context = ModelContext(container)
                    WidgetDataManager.refreshAll(modelContext: context)
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
