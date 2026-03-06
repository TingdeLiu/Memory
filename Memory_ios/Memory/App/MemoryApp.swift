import SwiftUI
import SwiftData

@main
struct MemoryApp: App {
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("autoLockOnBackground") private var autoLockOnBackground = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer {
        let schema = Schema([
            MemoryEntry.self,
            Contact.self,
            Message.self,
        ])

        let cloudKitDB: ModelConfiguration.CloudKitDatabase = iCloudSyncEnabled
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
    }

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if requireBiometricAuth && !isUnlocked {
                LockScreenView(isUnlocked: $isUnlocked)
            } else {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if requireBiometricAuth && autoLockOnBackground {
                    isUnlocked = false
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
