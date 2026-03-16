import SwiftUI
import SwiftData

struct AvatarSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var profile: AvatarProfile

    @State private var showingResetConfirm = false
    @State private var showingClearStylizedConfirm = false
    @State private var selectedColor: Color

    init(profile: AvatarProfile) {
        self.profile = profile
        self._selectedColor = State(initialValue: profile.backgroundColorValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Display Preferences
                Section {
                    Toggle(String(localized: "avatar.settings.show_in_chat"), isOn: $profile.showInChat)

                    Toggle(String(localized: "avatar.settings.show_in_profile"), isOn: $profile.showInProfile)

                    if profile.hasStylizedVersion {
                        Toggle(String(localized: "avatar.settings.use_stylized"), isOn: $profile.useStylizedVersion)
                    }
                } header: {
                    Text(String(localized: "avatar.settings.display_section"))
                } footer: {
                    Text(String(localized: "avatar.settings.display_footer"))
                }

                // Background Color
                Section {
                    ColorPicker(String(localized: "avatar.settings.background_color"), selection: $selectedColor)
                        .onChange(of: selectedColor) { _, newValue in
                            profile.backgroundColor = newValue.hexString
                            try? modelContext.save()
                        }

                    Button(String(localized: "avatar.settings.reset_color")) {
                        profile.backgroundColor = nil
                        selectedColor = profile.style.defaultBackgroundColor
                        try? modelContext.save()
                    }
                } header: {
                    Text(String(localized: "avatar.settings.appearance_section"))
                }

                // Status Section
                if profile.hasPhoto {
                    Section {
                        HStack {
                            Text(String(localized: "avatar.settings.has_photo"))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        HStack {
                            Text(String(localized: "avatar.settings.current_style"))
                            Spacer()
                            Text(profile.style.label)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(String(localized: "avatar.settings.current_frame"))
                            Spacer()
                            Text(profile.frameStyle.label)
                                .foregroundStyle(.secondary)
                        }

                        if profile.hasStylizedVersion {
                            HStack {
                                Text(String(localized: "avatar.settings.stylized_version"))
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.purple)
                                    Text(profile.stylizationStatus.rawValue.capitalized)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let date = profile.lastStylizedAt {
                                HStack {
                                    Text(String(localized: "avatar.settings.stylized_at"))
                                    Spacer()
                                    Text(date, style: .date)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "avatar.settings.status_section"))
                    }
                }

                // Data Management
                Section {
                    if profile.hasStylizedVersion {
                        Button(role: .destructive) {
                            showingClearStylizedConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles.slash")
                                Text(String(localized: "avatar.settings.clear_stylized"))
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(String(localized: "avatar.settings.reset"))
                        }
                    }
                    .disabled(!profile.hasPhoto)
                } header: {
                    Text(String(localized: "avatar.settings.data_section"))
                } footer: {
                    Text(String(localized: "avatar.settings.reset_footer"))
                }

                // Privacy
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "avatar.settings.privacy_title"))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(String(localized: "avatar.settings.privacy_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "avatar.settings.privacy_section"))
                }
            }
            .navigationTitle(String(localized: "avatar.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "avatar.settings.reset_confirm"), isPresented: $showingResetConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "avatar.settings.reset"), role: .destructive) {
                    profile.reset()
                    try? modelContext.save()
                }
            } message: {
                Text(String(localized: "avatar.settings.reset_message"))
            }
            .alert(String(localized: "avatar.settings.clear_stylized_confirm"), isPresented: $showingClearStylizedConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    profile.clearStylizedPhoto()
                    try? modelContext.save()
                }
            } message: {
                Text(String(localized: "avatar.settings.clear_stylized_message"))
            }
            .onChange(of: profile.showInChat) { _, _ in
                try? modelContext.save()
            }
            .onChange(of: profile.showInProfile) { _, _ in
                try? modelContext.save()
            }
            .onChange(of: profile.useStylizedVersion) { _, _ in
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    AvatarSettingsView(profile: AvatarProfile())
        .modelContainer(for: [AvatarProfile.self], inMemory: true)
}
