import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportService = DataExportService()
    @State private var showingExportOptions = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var stats: DataStatistics?

    var body: some View {
        List {
            // Data stats
            if let stats {
                statsSection(stats)
            }

            // Export
            Section {
                Button {
                    showingExportOptions = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "privacy.exportAll"))
                            Text(String(localized: "privacy.exportAllSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(exportService.isExporting)

                Button {
                    Task {
                        let url = await exportService.exportEncryptedBackup(
                            modelContainer: modelContext.container
                        )
                        if let url {
                            shareURL = url
                            showingShareSheet = true
                        }
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "privacy.encryptedBackup"))
                            Text(String(localized: "privacy.encryptedBackupSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.doc")
                    }
                }
                .disabled(exportService.isExporting)

                if exportService.isExporting {
                    HStack {
                        ProgressView()
                        Text(String(localized: "privacy.preparing"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = exportService.exportError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(String(localized: "privacy.export"))
            } footer: {
                Text(String(localized: "privacy.exportFooter"))
            }

            // Data protection info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoCard(
                        icon: "lock.shield.fill",
                        title: String(localized: "privacy.yourDataControl.title"),
                        description: String(localized: "privacy.yourDataControl.description")
                    )

                    InfoCard(
                        icon: "eye.slash.fill",
                        title: String(localized: "privacy.zeroKnowledge.title"),
                        description: String(localized: "privacy.zeroKnowledge.description")
                    )

                    InfoCard(
                        icon: "trash.slash.fill",
                        title: String(localized: "privacy.rightToDelete.title"),
                        description: String(localized: "privacy.rightToDelete.description")
                    )
                }
            } header: {
                Text(String(localized: "privacy.principles"))
            }

            // AI Privacy
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "privacy.aiFeatures"), systemImage: "brain")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(localized: "privacy.aiDescription"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(String(localized: "privacy.aiChoose"))
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(String(localized: "privacy.aiEncrypted"))
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(String(localized: "privacy.aiNoTraining"))
                            .font(.caption)
                    }
                }
            } header: {
                Text(String(localized: "privacy.aiPrivacy"))
            }

            // Delete all
            Section {
                Button(role: .destructive) {
                    showingDeleteAllAlert = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "privacy.deleteAll"))
                            Text(String(localized: "privacy.deleteAllSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "trash.fill")
                    }
                }
                .disabled(isDeleting)

                if isDeleting {
                    HStack {
                        ProgressView()
                        Text(String(localized: "privacy.deleting"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "privacy.dangerZone"))
            } footer: {
                Text(String(localized: "privacy.deleteAllFooter"))
            }
        }
        .navigationTitle(String(localized: "privacy.title"))
        .confirmationDialog(String(localized: "privacy.exportFormat"), isPresented: $showingExportOptions) {
            Button(String(localized: "privacy.jsonFormat")) {
                Task {
                    let url = await exportService.exportData(
                        format: .json,
                        modelContainer: modelContext.container
                    )
                    if let url {
                        shareURL = url
                        showingShareSheet = true
                    }
                }
            }
            Button(String(localized: "privacy.textFormat")) {
                Task {
                    let url = await exportService.exportData(
                        format: .plainText,
                        modelContainer: modelContext.container
                    )
                    if let url {
                        shareURL = url
                        showingShareSheet = true
                    }
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .alert(String(localized: "privacy.deleteAllConfirm.title"), isPresented: $showingDeleteAllAlert) {
            Button(String(localized: "privacy.deleteEverything"), role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "privacy.deleteAllConfirm.message"))
        }
        .alert(String(localized: "privacy.typeDelete"), isPresented: $showingDeleteConfirmation) {
            TextField("DELETE", text: $deleteConfirmText)
            Button(String(localized: "privacy.deleteForever"), role: .destructive) {
                if deleteConfirmText == "DELETE" {
                    performDeleteAll()
                }
                deleteConfirmText = ""
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                deleteConfirmText = ""
            }
        } message: {
            Text(String(localized: "privacy.typeDeleteMessage"))
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
                    .onDisappear {
                        exportService.cleanupExportFiles()
                    }
            }
        }
        .task {
            await loadStats()
        }
    }

    // MARK: - Stats

    private func statsSection(_ stats: DataStatistics) -> some View {
        Section(String(localized: "privacy.yourData")) {
            DataStatRow(label: String(localized: "privacy.memories"), value: "\(stats.totalMemories)", icon: "brain", color: Color.accentColor)
            if stats.textMemories > 0 {
                DataStatRow(label: String(localized: "privacy.text"), value: "\(stats.textMemories)", icon: "doc.text", color: .blue)
            }
            if stats.audioMemories > 0 {
                DataStatRow(label: String(localized: "privacy.voice"), value: "\(stats.audioMemories)", icon: "waveform", color: .orange)
            }
            if stats.photoMemories > 0 {
                DataStatRow(label: String(localized: "privacy.photo"), value: "\(stats.photoMemories)", icon: "photo", color: .green)
            }
            if stats.privateMemories > 0 {
                DataStatRow(label: String(localized: "privacy.private"), value: "\(stats.privateMemories)", icon: "lock.fill", color: .red)
            }

            DataStatRow(label: String(localized: "privacy.contacts"), value: "\(stats.totalContacts)", icon: "person.2", color: Color.accentColor)
            DataStatRow(label: String(localized: "privacy.messages"), value: "\(stats.totalMessages)", icon: "envelope", color: .blue)

            if stats.sealedMessages > 0 {
                DataStatRow(label: String(localized: "privacy.sealed"), value: "\(stats.sealedMessages)", icon: "infinity", color: .purple)
            }

            if let oldest = stats.oldestMemoryDate {
                HStack {
                    Text(String(localized: "privacy.archivingSince"))
                        .font(.subheadline)
                    Spacer()
                    Text(oldest.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func performDeleteAll() {
        isDeleting = true
        Task {
            let storage = StorageService(modelContainer: modelContext.container)
            try? await storage.deleteAllData()
            EncryptionHelper.deleteMasterKey()
            await MainActor.run {
                isDeleting = false
                stats = nil
            }
        }
    }

    private func loadStats() async {
        let storage = StorageService(modelContainer: modelContext.container)
        stats = try? await storage.getStatistics()
    }
}

// MARK: - Helper Views

struct DataStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// UIKit ShareSheet wrapper for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
    .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
