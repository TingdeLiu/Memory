import SwiftUI
import SwiftData

struct DigitalSelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var configs: [DigitalSelfConfig]
    @Query private var soulProfiles: [SoulProfile]
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var writingProfiles: [WritingStyleProfile]
    @Query private var avatarProfiles: [AvatarProfile]
    @Query private var contacts: [Contact]

    @State private var showingSettings = false
    @State private var showingChat = false
    @State private var selectedContact: Contact?
    @State private var showingContactPicker = false
    @State private var showingPurchase = false

    private let storeService = StoreService.shared

    private var config: DigitalSelfConfig {
        configs.first ?? createDefaultConfig()
    }

    private var soulProfile: SoulProfile? {
        soulProfiles.first
    }

    private var voiceProfile: VoiceProfile? {
        voiceProfiles.first
    }

    private var writingProfile: WritingStyleProfile? {
        writingProfiles.first
    }

    private var avatarProfile: AvatarProfile? {
        avatarProfiles.first
    }

    private var componentStatuses: [DigitalSelfComponentStatus] {
        DigitalSelfService.shared.checkComponentStatus(
            soulProfile: soulProfile,
            voiceProfile: voiceProfile,
            writingProfile: writingProfile,
            avatarProfile: avatarProfile
        )
    }

    private var readyComponents: Int {
        componentStatuses.filter { $0.isReady }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if storeService.canUseDigitalSelf {
                    mainContent
                } else {
                    premiumRequiredView
                }
            }
            .navigationTitle(String(localized: "digitalself.title"))
            .toolbar {
                if storeService.canUseDigitalSelf {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DigitalSelfSettingsView()
            }
            .sheet(isPresented: $showingChat) {
                if let contact = selectedContact {
                    DigitalSelfChatView(contact: contact)
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                contactPickerSheet
            }
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
            .onAppear {
                ensureConfigExists()
                updateComponentStatus()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Header
                statusCard

                // Components Progress
                componentsSection

                // Quick Actions (when ready)
                if config.isReady {
                    actionsSection
                }

                // Access Control
                if config.isReady {
                    accessSection
                }

                // Statistics
                if config.totalConversations > 0 {
                    statisticsSection
                }
            }
            .padding()
        }
    }

    // MARK: - Premium Required View

    private var premiumRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }

            // Title
            Text(String(localized: "digitalself.premium.title"))
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(String(localized: "digitalself.premium.description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Features List
            VStack(alignment: .leading, spacing: 12) {
                premiumFeatureRow(icon: "bubble.left.and.bubble.right.fill", text: String(localized: "digitalself.premium.feature.chat"))
                premiumFeatureRow(icon: "waveform", text: String(localized: "digitalself.premium.feature.voice"))
                premiumFeatureRow(icon: "person.2.fill", text: String(localized: "digitalself.premium.feature.contacts"))
                premiumFeatureRow(icon: "lock.shield.fill", text: String(localized: "digitalself.premium.feature.privacy"))
            }
            .padding(.vertical)

            Spacer()

            // Upgrade Button
            Button {
                showingPurchase = true
            } label: {
                Text(String(localized: "digitalself.premium.upgrade"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func premiumFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            // Avatar and Status
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    if let avatarProfile = avatarProfile,
                       let photoData = avatarProfile.originalPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                            }
                    }

                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 3)
                        }
                        .offset(x: 28, y: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(soulProfile?.displayName ?? String(localized: "digitalself.unnamed"))
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        Image(systemName: config.currentStatus.icon)
                        Text(config.currentStatus.label)
                    }
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                    Text(String(localized: "digitalself.components_ready \(readyComponents) \(4)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Enable/Disable Toggle (when ready)
            if config.isReady {
                Toggle(isOn: Binding(
                    get: { config.isEnabled },
                    set: { newValue in
                        config.isEnabled = newValue
                        config.currentStatus = newValue ? .active : .ready
                        try? modelContext.save()
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "digitalself.enable"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "digitalself.enable.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private var statusColor: Color {
        switch config.currentStatus {
        case .notReady: return .secondary
        case .ready: return .blue
        case .active: return .green
        case .paused: return .orange
        }
    }

    // MARK: - Components Section

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "digitalself.components"))
                .font(.headline)

            ForEach(componentStatuses, id: \.name) { component in
                componentRow(component)
            }
        }
    }

    private func componentRow(_ component: DigitalSelfComponentStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: component.icon)
                .font(.title3)
                .foregroundStyle(component.isReady ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(component.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(component.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if component.isReady {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: component.progress)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 24, height: 24)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "digitalself.actions"))
                .font(.headline)

            Button {
                showingContactPicker = true
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title2)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading) {
                        Text(String(localized: "digitalself.action.chat"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "digitalself.action.chat.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Access Section

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "digitalself.access"))
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(DigitalSelfAccessMode.allCases, id: \.self) { mode in
                    accessModeRow(mode)
                }
            }

            if config.currentAccessMode == .selectedContacts {
                allowedContactsList
            }
        }
    }

    private func accessModeRow(_ mode: DigitalSelfAccessMode) -> some View {
        Button {
            config.currentAccessMode = mode
            try? modelContext.save()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(mode.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if config.currentAccessMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.purple)
                }
            }
            .padding()
            .background(
                config.currentAccessMode == mode
                    ? Color.purple.opacity(0.1)
                    : Color(.secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var allowedContactsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "digitalself.allowed_contacts"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(String(localized: "common.edit")) {
                    showingContactPicker = true
                }
                .font(.caption)
            }

            let allowedContacts = contacts.filter { config.isContactAllowed($0.id) }
            if allowedContacts.isEmpty {
                Text(String(localized: "digitalself.no_contacts_selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allowedContacts) { contact in
                            VStack {
                                ContactAvatarSmall(contact: contact)
                                Text(contact.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "digitalself.statistics"))
                .font(.headline)

            HStack(spacing: 16) {
                statisticBox(
                    title: String(localized: "digitalself.stat.conversations"),
                    value: "\(config.totalConversations)",
                    icon: "bubble.left.and.bubble.right"
                )

                statisticBox(
                    title: String(localized: "digitalself.stat.messages"),
                    value: "\(config.totalMessages)",
                    icon: "message"
                )
            }

            if let lastDate = config.lastInteractionDate {
                Text(String(localized: "digitalself.last_interaction \(lastDate.formatted(.relative(presentation: .named)))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statisticBox(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)

            VStack(alignment: .leading) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Contact Picker Sheet

    private var contactPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(contacts) { contact in
                    Button {
                        if config.currentAccessMode == .selectedContacts {
                            // Toggle contact access
                            if config.isContactAllowed(contact.id) {
                                config.removeAllowedContact(contact.id)
                            } else {
                                config.addAllowedContact(contact.id)
                            }
                            try? modelContext.save()
                        } else {
                            // Start chat with contact
                            selectedContact = contact
                            showingContactPicker = false
                            showingChat = true
                        }
                    } label: {
                        HStack {
                            ContactAvatarSmall(contact: contact)
                            Text(contact.name)
                            Spacer()
                            if config.currentAccessMode == .selectedContacts {
                                if config.isContactAllowed(contact.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.purple)
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(
                config.currentAccessMode == .selectedContacts
                    ? String(localized: "digitalself.select_contacts")
                    : String(localized: "digitalself.chat_with")
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        showingContactPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func createDefaultConfig() -> DigitalSelfConfig {
        let config = DigitalSelfConfig()
        modelContext.insert(config)
        try? modelContext.save()
        return config
    }

    private func ensureConfigExists() {
        if configs.isEmpty {
            _ = createDefaultConfig()
        }
    }

    private func updateComponentStatus() {
        let config = configs.first ?? createDefaultConfig()

        let soulReady = (soulProfile?.profileCompleteness ?? 0) >= 0.3
        let voiceReady = voiceProfile?.status == .ready
        let writingReady = writingProfile?.status == .ready
        let avatarReady = avatarProfile?.hasPhoto == true

        config.updateComponentStatus(
            soulProfile: soulReady,
            voiceClone: voiceReady,
            writingStyle: writingReady,
            avatar: avatarReady
        )
        try? modelContext.save()
    }
}

// MARK: - Small Contact Avatar

private struct ContactAvatarSmall: View {
    let contact: Contact

    var body: some View {
        ZStack {
            Circle()
                .fill(contact.relationship.color.opacity(0.2))
                .frame(width: 40, height: 40)

            if let photoData = contact.avatarData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(contact.relationship.color)
            }
        }
    }
}

#Preview {
    DigitalSelfView()
        .modelContainer(for: [DigitalSelfConfig.self, SoulProfile.self, VoiceProfile.self, WritingStyleProfile.self, AvatarProfile.self, Contact.self], inMemory: true)
}
