import SwiftUI
import SwiftData

struct VoiceSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [VoiceProfile]
    @Query private var samples: [VoiceSample]

    @State private var selectedProvider: VoiceCloneProvider = .elevenLabs
    @State private var apiKey = ""
    @State private var customEndpoint = ""
    @State private var showingDeleteConfirm = false
    @State private var showingResetConfirm = false

    private var profile: VoiceProfile? {
        profiles.first
    }

    private var voiceService = VoiceCloneService.shared

    var body: some View {
        NavigationStack {
            Form {
                // Provider Selection
                Section {
                    Picker(String(localized: "voice.settings.provider"), selection: $selectedProvider) {
                        ForEach(VoiceCloneProvider.allCases, id: \.self) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }

                    Text(selectedProvider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "voice.settings.provider_section"))
                }

                // API Key
                Section {
                    SecureField(String(localized: "voice.settings.api_key"), text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    if voiceService.hasAPIKey(for: selectedProvider) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(String(localized: "voice.settings.api_key_saved"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(String(localized: "voice.settings.save_api_key")) {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)

                    if voiceService.hasAPIKey(for: selectedProvider) {
                        Button(String(localized: "voice.settings.delete_api_key"), role: .destructive) {
                            voiceService.deleteAPIKey(for: selectedProvider)
                            apiKey = ""
                        }
                    }
                } header: {
                    Text(String(localized: "voice.settings.api_section"))
                } footer: {
                    if selectedProvider == .elevenLabs {
                        Text(String(localized: "voice.settings.elevenlabs_footer"))
                    }
                }

                // Custom Endpoint (for custom provider)
                if selectedProvider == .custom {
                    Section {
                        TextField(String(localized: "voice.settings.endpoint"), text: $customEndpoint)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button(String(localized: "voice.settings.save_endpoint")) {
                            profile?.customEndpoint = customEndpoint
                            try? modelContext.save()
                        }
                        .disabled(customEndpoint.isEmpty)
                    } header: {
                        Text(String(localized: "voice.settings.endpoint_section"))
                    }
                }

                // ElevenLabs Model Selection
                if selectedProvider == .elevenLabs {
                    Section {
                        Picker(String(localized: "voice.settings.model"), selection: Binding(
                            get: { profile?.elevenLabsModelId ?? ElevenLabsModel.multilingualV2.rawValue },
                            set: { profile?.elevenLabsModelId = $0; try? modelContext.save() }
                        )) {
                            ForEach(ElevenLabsModel.allCases, id: \.rawValue) { model in
                                VStack(alignment: .leading) {
                                    Text(model.label)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(model.rawValue)
                            }
                        }
                    } header: {
                        Text(String(localized: "voice.settings.model_section"))
                    }
                }

                // Current Voice Status
                if let profile = profile, profile.isReady {
                    Section {
                        HStack {
                            Text(String(localized: "voice.settings.voice_name"))
                            Spacer()
                            Text(profile.voiceName ?? "-")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(String(localized: "voice.settings.voice_id"))
                            Spacer()
                            Text(profile.voiceId ?? "-")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let date = profile.lastTrainedAt {
                            HStack {
                                Text(String(localized: "voice.settings.trained_at"))
                                Spacer()
                                Text(date, style: .date)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(String(localized: "voice.settings.current_voice"))
                    }
                }

                // Data Management
                Section {
                    HStack {
                        Text(String(localized: "voice.settings.samples_count"))
                        Spacer()
                        Text("\(samples.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "voice.settings.total_duration"))
                        Spacer()
                        Text(formatDuration(profile?.totalDuration ?? 0))
                            .foregroundStyle(.secondary)
                    }

                    Button(String(localized: "voice.settings.reset"), role: .destructive) {
                        showingResetConfirm = true
                    }

                    if profile?.isReady == true {
                        Button(String(localized: "voice.settings.delete_voice"), role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                } header: {
                    Text(String(localized: "voice.settings.data_section"))
                } footer: {
                    Text(String(localized: "voice.settings.data_footer"))
                }

                // Privacy
                Section {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading) {
                            Text(String(localized: "voice.settings.privacy_title"))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(String(localized: "voice.settings.privacy_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "voice.settings.privacy_section"))
                }
            }
            .navigationTitle(String(localized: "voice.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "voice.settings.reset_confirm"), isPresented: $showingResetConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "voice.settings.reset"), role: .destructive) {
                    resetAll()
                }
            } message: {
                Text(String(localized: "voice.settings.reset_message"))
            }
            .alert(String(localized: "voice.settings.delete_confirm"), isPresented: $showingDeleteConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteVoice()
                }
            } message: {
                Text(String(localized: "voice.settings.delete_message"))
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: selectedProvider) { _, newValue in
                profile?.provider = newValue
                try? modelContext.save()
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        selectedProvider = profile?.provider ?? .elevenLabs
        customEndpoint = profile?.customEndpoint ?? ""
    }

    private func saveAPIKey() {
        voiceService.saveAPIKey(apiKey, for: selectedProvider)
        apiKey = ""
    }

    private func resetAll() {
        // Delete all samples
        for sample in samples {
            if let url = sample.audioURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(sample)
        }

        // Reset profile
        profile?.reset()

        try? modelContext.save()
    }

    private func deleteVoice() {
        guard let profile = profile else { return }

        Task {
            try? await voiceService.deleteVoice(profile: profile)
            try? modelContext.save()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VoiceSettingsView()
        .modelContainer(for: [VoiceProfile.self, VoiceSample.self], inMemory: true)
}
