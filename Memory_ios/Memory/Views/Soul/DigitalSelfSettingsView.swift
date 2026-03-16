import SwiftUI
import SwiftData

struct DigitalSelfSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var configs: [DigitalSelfConfig]
    @Query private var soulProfiles: [SoulProfile]
    @Query private var voiceProfiles: [VoiceProfile]

    @State private var showingResetConfirm = false

    private var config: DigitalSelfConfig? {
        configs.first
    }

    private var soulProfile: SoulProfile? {
        soulProfiles.first
    }

    private var voiceProfile: VoiceProfile? {
        voiceProfiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status Section
                statusSection

                // Personality Section
                personalitySection

                // Voice Section
                voiceSection

                // Behavior Section
                behaviorSection

                // Statistics Section
                if let config = config, config.totalConversations > 0 {
                    statisticsSection
                }

                // Privacy Section
                privacySection

                // Data Section
                dataSection
            }
            .navigationTitle(String(localized: "digitalself.settings.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "digitalself.settings.reset_confirm"), isPresented: $showingResetConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "digitalself.settings.reset"), role: .destructive) {
                    resetDigitalSelf()
                }
            } message: {
                Text(String(localized: "digitalself.settings.reset_message"))
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            if let config = config {
                HStack {
                    Text(String(localized: "digitalself.settings.status"))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: config.currentStatus.icon)
                        Text(config.currentStatus.label)
                    }
                    .foregroundStyle(statusColor(for: config.currentStatus))
                }

                HStack {
                    Text(String(localized: "digitalself.settings.readiness"))
                    Spacer()
                    Text("\(Int(config.readinessScore * 100))%")
                        .foregroundStyle(.secondary)
                }

                if config.isReady {
                    Toggle(String(localized: "digitalself.enable"), isOn: Binding(
                        get: { config.isEnabled },
                        set: { newValue in
                            config.isEnabled = newValue
                            config.currentStatus = newValue ? .active : .ready
                            try? modelContext.save()
                        }
                    ))
                }
            }
        } header: {
            Text(String(localized: "digitalself.settings.status_section"))
        }
    }

    private func statusColor(for status: DigitalSelfStatus) -> Color {
        switch status {
        case .notReady: return .secondary
        case .ready: return .blue
        case .active: return .green
        case .paused: return .orange
        }
    }

    // MARK: - Personality Section

    private var personalitySection: some View {
        Section {
            if let config = config {
                Picker(String(localized: "digitalself.settings.personality_mode"), selection: Binding(
                    get: { config.currentPersonalityMode },
                    set: { newValue in
                        config.currentPersonalityMode = newValue
                        try? modelContext.save()
                    }
                )) {
                    ForEach(DigitalSelfPersonalityMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "digitalself.settings.emotional_level"))
                        Spacer()
                        Text(emotionalLevelLabel(config.emotionalResponseLevel))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { config.emotionalResponseLevel },
                        set: { newValue in
                            config.emotionalResponseLevel = newValue
                            try? modelContext.save()
                        }
                    ), in: 0...1)
                }
            }
        } header: {
            Text(String(localized: "digitalself.settings.personality_section"))
        } footer: {
            if let config = config {
                Text(config.currentPersonalityMode.description)
            }
        }
    }

    private func emotionalLevelLabel(_ level: Double) -> String {
        if level < 0.3 {
            return String(localized: "digitalself.emotional.reserved")
        } else if level < 0.7 {
            return String(localized: "digitalself.emotional.balanced")
        } else {
            return String(localized: "digitalself.emotional.expressive")
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            if let config = config {
                Toggle(String(localized: "digitalself.settings.voice_output"), isOn: Binding(
                    get: { config.voiceOutputEnabled },
                    set: { newValue in
                        config.voiceOutputEnabled = newValue
                        try? modelContext.save()
                    }
                ))
                .disabled(voiceProfile?.status != .ready)

                if voiceProfile?.status != .ready {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.orange)
                        Text(String(localized: "digitalself.settings.voice_not_ready"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "digitalself.settings.voice_section"))
        } footer: {
            Text(String(localized: "digitalself.settings.voice_footer"))
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        Section {
            if let config = config {
                Toggle(String(localized: "digitalself.settings.auto_greet"), isOn: Binding(
                    get: { config.autoGreetEnabled },
                    set: { newValue in
                        config.autoGreetEnabled = newValue
                        try? modelContext.save()
                    }
                ))
            }
        } header: {
            Text(String(localized: "digitalself.settings.behavior_section"))
        } footer: {
            Text(String(localized: "digitalself.settings.auto_greet_footer"))
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        Section {
            if let config = config {
                HStack {
                    Text(String(localized: "digitalself.stat.conversations"))
                    Spacer()
                    Text("\(config.totalConversations)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "digitalself.stat.messages"))
                    Spacer()
                    Text("\(config.totalMessages)")
                        .foregroundStyle(.secondary)
                }

                if let lastDate = config.lastInteractionDate {
                    HStack {
                        Text(String(localized: "digitalself.settings.last_interaction"))
                        Spacer()
                        Text(lastDate, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "digitalself.settings.statistics_section"))
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text(String(localized: "digitalself.settings.privacy_title"))
                        .fontWeight(.medium)
                }

                Text(String(localized: "digitalself.settings.privacy_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "digitalself.settings.privacy_section"))
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                HStack {
                    Text(String(localized: "digitalself.settings.reset"))
                    Spacer()
                    Image(systemName: "trash")
                }
            }
        } header: {
            Text(String(localized: "digitalself.settings.data_section"))
        } footer: {
            Text(String(localized: "digitalself.settings.reset_footer"))
        }
    }

    // MARK: - Actions

    private func resetDigitalSelf() {
        guard let config = config else { return }

        config.isEnabled = false
        config.currentStatus = .notReady
        config.totalConversations = 0
        config.totalMessages = 0
        config.lastInteractionDate = nil
        config.conversationHistoryData = nil
        config.allowedContactIds = []

        try? modelContext.save()
    }
}

#Preview {
    DigitalSelfSettingsView()
        .modelContainer(for: [DigitalSelfConfig.self, SoulProfile.self, VoiceProfile.self], inMemory: true)
}
