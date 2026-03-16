import Foundation
import SwiftData
import Observation

/// Global container for application-wide services to support Dependency Injection.
@Observable
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    let aiService: AIService
    let storeService: StoreService
    let cloudSyncService: CloudSyncService
    let googleDriveSyncService: GoogleDriveSyncService
    
    init(
        aiService: AIService = AIService(),
        storeService: StoreService = StoreService.shared,
        cloudSyncService: CloudSyncService = CloudSyncService.shared,
        googleDriveSyncService: GoogleDriveSyncService = GoogleDriveSyncService.shared
    ) {
        self.aiService = aiService
        self.storeService = storeService
        self.cloudSyncService = cloudSyncService
        self.googleDriveSyncService = googleDriveSyncService
    }
    
    /// Provides a mock container for SwiftUI Previews.
    static var mock: DependencyContainer {
        DependencyContainer()
    }
}
