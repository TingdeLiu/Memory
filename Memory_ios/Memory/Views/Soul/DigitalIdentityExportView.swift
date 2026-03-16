import SwiftUI
import SwiftData

struct DigitalIdentityExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var soulProfiles: [SoulProfile]
    @Query private var writingProfiles: [WritingStyleProfile]
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var avatarProfiles: [AvatarProfile]
    @Query private var memories: [MemoryEntry]
    @Query private var contacts: [Contact]
    @Query private var messages: [Message]
    @Query private var relationshipProfiles: [RelationshipProfile]

    private var exportService: DigitalIdentityExportService { DigitalIdentityExportService.shared }

    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?
    @State private var exportedURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Data Summary
                    dataSummarySection

                    // File Preview
                    filePreviewSection

                    // Export Button
                    exportButtonSection

                    // Last Export
                    if let lastDate = exportService.lastExportDate {
                        lastExportSection(lastDate)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert(String(localized: "export.error.title"), isPresented: .init(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button(String(localized: "common.ok")) {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(localized: "export.header.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(localized: "export.header.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    // MARK: - Data Summary

    private var dataSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "export.summary.title"))
                .font(.headline)

            VStack(spacing: 8) {
                summaryRow(icon: "person.crop.circle.badge.moon", label: String(localized: "export.summary.soul"), value: soulProfiles.isEmpty ? String(localized: "export.summary.notSet") : String(localized: "export.summary.ready"))

                summaryRow(icon: "brain.head.profile", label: String(localized: "export.summary.memories"), value: "\(memories.count)")

                summaryRow(icon: "person.2.fill", label: String(localized: "export.summary.contacts"), value: "\(contacts.count)")

                summaryRow(icon: "envelope.fill", label: String(localized: "export.summary.messages"), value: "\(messages.count)")

                summaryRow(icon: "pencil.line", label: String(localized: "export.summary.writing"), value: writingProfiles.first?.isReady == true ? String(localized: "export.summary.ready") : String(localized: "export.summary.notSet"))

                summaryRow(icon: "waveform.circle", label: String(localized: "export.summary.voice"), value: voiceProfiles.first?.isReady == true ? String(localized: "export.summary.ready") : String(localized: "export.summary.notSet"))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    // MARK: - File Preview

    private var filePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "export.files.title"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                fileRow("SOUL.md", desc: String(localized: "export.file.soul"))
                fileRow("WRITING_STYLE.md", desc: String(localized: "export.file.writing"))
                fileRow("VOICE.md", desc: String(localized: "export.file.voice"))
                fileRow("AI_PROMPT.md", desc: String(localized: "export.file.prompt"))
                fileRow("MEMORIES/", desc: String(localized: "export.file.memories"))
                fileRow("RELATIONSHIPS/", desc: String(localized: "export.file.relationships"))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func fileRow(_ name: String, desc: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: name.hasSuffix("/") ? "folder.fill" : "doc.fill")
                .foregroundStyle(name.hasSuffix("/") ? .blue : .orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontDesign(.monospaced)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Export Button

    private var exportButtonSection: some View {
        VStack(spacing: 12) {
            Button {
                startExport()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? String(localized: "export.button.exporting") : String(localized: "export.button.export"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isExporting || soulProfiles.isEmpty)

            if soulProfiles.isEmpty {
                Text(String(localized: "export.hint.needSoul"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if isExporting {
                ProgressView(value: exportService.exportProgress)
                    .progressViewStyle(.linear)
            }

            if exportComplete, let url = exportedURL {
                Button {
                    showingShareSheet = true
                } label: {
                    Label(String(localized: "export.button.share"), systemImage: "square.and.arrow.up.on.square")
                        .font(.subheadline)
                }

                Text(String(localized: "export.success.path"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(url.path)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Last Export

    private func lastExportSection(_ date: Date) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text(String(localized: "export.lastExport"))
            Spacer()
            Text(date, style: .relative)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Export

    private func startExport() {
        isExporting = true
        exportComplete = false
        exportError = nil

        Task {
            do {
                let url = try await exportService.exportAll(
                    soulProfile: soulProfiles.first,
                    writingProfile: writingProfiles.first,
                    voiceProfile: voiceProfiles.first,
                    avatarProfile: avatarProfiles.first,
                    memories: memories,
                    contacts: contacts,
                    messages: messages,
                    relationshipProfiles: relationshipProfiles
                )
                await MainActor.run {
                    exportedURL = url
                    exportComplete = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Share Sheet
// Note: Uses ShareSheet from PrivacySettingsView.swift

#Preview {
    DigitalIdentityExportView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self, SoulProfile.self, WritingStyleProfile.self, VoiceProfile.self, AvatarProfile.self, RelationshipProfile.self], inMemory: true)
}
