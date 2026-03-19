import Foundation
import CloudKit
import SwiftUI

/// Manages iCloud sync state, monitoring, and configuration.
/// SwiftData handles actual CloudKit sync automatically when configured
/// with a CloudKit database in ModelConfiguration. This service monitors
/// the sync state and provides user-facing status.
@Observable
final class CloudSyncService {
    var syncStatus: SyncStatus = .unknown
    var lastSyncDate: Date?
    var iCloudAvailable = false
    var accountName: String?
    var storageUsed: String?

    static let shared = CloudSyncService()

    enum SyncStatus: Equatable {
        case unknown
        case checking
        case available
        case syncing
        case synced
        case noAccount
        case restricted
        case error(String)

        var label: String {
            switch self {
            case .unknown: return "Unknown"
            case .checking: return "Checking..."
            case .available: return "Ready"
            case .syncing: return "Syncing..."
            case .synced: return "Up to date"
            case .noAccount: return "Not signed in"
            case .restricted: return "Restricted"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var icon: String {
            switch self {
            case .unknown, .checking: return "icloud.slash"
            case .available, .synced: return "checkmark.icloud"
            case .syncing: return "icloud.and.arrow.up"
            case .noAccount: return "icloud.slash"
            case .restricted: return "exclamationmark.icloud"
            case .error: return "xmark.icloud"
            }
        }

        var color: Color {
            switch self {
            case .synced, .available: return .green
            case .syncing, .checking: return .blue
            case .noAccount: return .orange
            case .restricted, .error: return .red
            case .unknown: return .secondary
            }
        }
    }

    private lazy var container: CKContainer = {
        CKContainer.default()
    }()
    private var notificationObserver: (any NSObjectProtocol)?

    init() {
        setupNotifications()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Account Status

    /// Check if the user is signed into iCloud and update state.
    @MainActor
    func checkiCloudStatus() async {
        syncStatus = .checking
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                iCloudAvailable = true
                syncStatus = .available
                await fetchAccountInfo()
            case .noAccount:
                iCloudAvailable = false
                syncStatus = .noAccount
            case .restricted:
                iCloudAvailable = false
                syncStatus = .restricted
            case .couldNotDetermine:
                iCloudAvailable = false
                syncStatus = .unknown
            case .temporarilyUnavailable:
                iCloudAvailable = false
                syncStatus = .error("Temporarily unavailable")
            @unknown default:
                iCloudAvailable = false
                syncStatus = .unknown
            }
        } catch {
            iCloudAvailable = false
            syncStatus = .error(error.localizedDescription)
        }
    }

    /// Fetch iCloud account identity info.
    private func fetchAccountInfo() async {
        do {
            let id = try await container.userRecordID()
            await MainActor.run {
                accountName = id.recordName == "__defaultOwner__" ? "Your iCloud" : id.recordName
            }
        } catch {
            // Non-critical — just leave accountName nil
        }
    }

    // MARK: - Sync Monitoring

    /// Listen for CloudKit account change notifications.
    private func setupNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkiCloudStatus()
            }
        }
    }

    /// Mark sync as completed (called after observing successful data operations).
    @MainActor
    func markSynced() {
        syncStatus = .synced
        lastSyncDate = Date()
    }

    // MARK: - Zone Operations

    /// Verify the private database zone exists. Creates it if needed.
    func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        let database = container.privateCloudDatabase

        do {
            _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        } catch {
            // Zone likely already exists — that's fine
        }
    }

    // MARK: - Conflict Resolution

    /// Resolve sync conflicts using "last write wins" strategy.
    /// SwiftData/CloudKit handles most conflicts automatically,
    /// but this provides a hook for custom resolution if needed.
    func resolveConflict(serverRecord: CKRecord, clientRecord: CKRecord) -> CKRecord {
        let serverDate = serverRecord.modificationDate ?? .distantPast
        let clientDate = clientRecord.modificationDate ?? .distantPast

        // Last-write-wins
        return clientDate > serverDate ? clientRecord : serverRecord
    }

    // MARK: - Storage Info

    /// Estimate local storage usage.
    func calculateLocalStorageSize() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        // SwiftData store
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            totalSize += directorySize(at: appSupport)
        }

        // Audio recordings
        let recordings = AudioRecordingService.recordingsDirectory
        totalSize += directorySize(at: recordings)

        return totalSize
    }

    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }

    /// Format bytes into human-readable string.
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
