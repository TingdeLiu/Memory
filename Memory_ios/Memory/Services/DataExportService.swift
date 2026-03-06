import Foundation
import SwiftUI
import SwiftData

/// Coordinates data export and provides shareable file URLs.
@Observable
final class DataExportService {
    var isExporting = false
    var exportError: String?
    var exportedFileURL: URL?

    enum ExportFormat {
        case json
        case plainText
    }

    /// Export data to a temporary file and return its URL for sharing.
    func exportData(
        format: ExportFormat,
        modelContainer: ModelContainer
    ) async -> URL? {
        await MainActor.run { isExporting = true; exportError = nil }
        defer { Task { @MainActor in isExporting = false } }

        let storage = StorageService(modelContainer: modelContainer)
        let tempDir = FileManager.default.temporaryDirectory
        let dateStr = Date().formatted(.iso8601.year().month().day())

        do {
            switch format {
            case .json:
                let data = try await storage.exportAllDataAsJSON()
                let url = tempDir.appendingPathComponent("Memory-Export-\(dateStr).json")
                try data.write(to: url)
                await MainActor.run { exportedFileURL = url }
                return url

            case .plainText:
                let text = try await storage.exportAsPlainText()
                let url = tempDir.appendingPathComponent("Memory-Export-\(dateStr).txt")
                try text.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run { exportedFileURL = url }
                return url
            }
        } catch {
            await MainActor.run { exportError = error.localizedDescription }
            return nil
        }
    }

    /// Export encrypted data (JSON encrypted with master key).
    func exportEncryptedBackup(modelContainer: ModelContainer) async -> URL? {
        await MainActor.run { isExporting = true; exportError = nil }
        defer { Task { @MainActor in isExporting = false } }

        let storage = StorageService(modelContainer: modelContainer)
        let tempDir = FileManager.default.temporaryDirectory
        let dateStr = Date().formatted(.iso8601.year().month().day())

        do {
            let data = try await storage.exportAllDataAsJSON()
            let key = try EncryptionHelper.masterKey()
            let encrypted = try EncryptionHelper.encrypt(data, using: key)

            let url = tempDir.appendingPathComponent("Memory-Backup-\(dateStr).membackup")
            try encrypted.write(to: url)
            await MainActor.run { exportedFileURL = url }
            return url
        } catch {
            await MainActor.run { exportError = error.localizedDescription }
            return nil
        }
    }

    /// Clean up temporary export files.
    func cleanupExportFiles() {
        if let url = exportedFileURL {
            try? FileManager.default.removeItem(at: url)
            exportedFileURL = nil
        }
    }
}
