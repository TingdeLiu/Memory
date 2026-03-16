import SwiftUI
import SwiftData

struct SoulTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [SoulProfile]
    @Query private var interviews: [InterviewSession]
    @Query private var assessments: [AssessmentResult]
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var writingProfiles: [WritingStyleProfile]
    @Query private var avatarProfiles: [AvatarProfile]
    @Query private var digitalSelfConfigs: [DigitalSelfConfig]

    @State private var showingInterview = false
    @State private var showingAssessments = false
    @State private var showingProfile = false
    @State private var showingVoiceClone = false
    @State private var showingWritingStyle = false
    @State private var showingAvatar = false
    @State private var showingDigitalSelf = false
    @State private var showingLightOrbUniverse = false
    @State private var selectedInterviewType: InterviewType?

    private var profile: SoulProfile? {
        profiles.first
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

    private var digitalSelfConfig: DigitalSelfConfig? {
        digitalSelfConfigs.first
    }

    private var completedInterviews: [InterviewSession] {
        interviews.filter { $0.isComplete }.sorted { $0.completedAt ?? $0.createdAt > $1.completedAt ?? $1.createdAt }
    }

    private var completedAssessments: [AssessmentResult] {
        assessments.filter { $0.isComplete }.sorted { $0.completedAt ?? $0.createdAt > $1.completedAt ?? $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Card
                    profileCard

                    // Progress Section
                    progressSection

                    // Quick Actions
                    quickActionsSection

                    // Recent Activity
                    if !completedInterviews.isEmpty || !completedAssessments.isEmpty {
                        recentActivitySection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "soul.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.text.rectangle")
                    }
                    .disabled(profile == nil)
                }
            }
            .sheet(isPresented: $showingInterview) {
                if let type = selectedInterviewType {
                    InterviewView(interviewType: type)
                }
            }
            .sheet(isPresented: $showingAssessments) {
                AssessmentListView()
            }
            .sheet(isPresented: $showingProfile) {
                if let profile = profile {
                    SoulProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showingVoiceClone) {
                VoiceCloneView()
            }
            .sheet(isPresented: $showingWritingStyle) {
                WritingStyleView()
            }
            .sheet(isPresented: $showingAvatar) {
                AvatarView()
            }
            .sheet(isPresented: $showingDigitalSelf) {
                DigitalSelfView()
            }
            .fullScreenCover(isPresented: $showingLightOrbUniverse) {
                LightOrbUniverseView()
            }
            .onAppear {
                ensureProfileExists()
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            // Avatar and Name
            HStack(spacing: 16) {
                // Avatar Circle - Tap to open Light Orb Universe
                Button {
                    showingLightOrbUniverse = true
                } label: {
                    ZStack {
                        // Outer glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.1), .clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .purple.opacity(0.5), radius: 8)

                        if let nickname = profile?.nickname, let firstChar = nickname.first {
                            Text(String(firstChar).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }

                        // Sparkle indicator
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .offset(x: 30, y: -30)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.displayName ?? String(localized: "soul.greeting"))
                        .font(.title2)
                        .fontWeight(.bold)

                    if let mbti = profile?.mbtiType {
                        HStack(spacing: 4) {
                            Text(mbti)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())

                            if let desc = MBTIType(rawValue: mbti)?.nickname {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let age = profile?.age {
                        Text(String(localized: "soul.age \(age)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Hint to tap avatar
                    Text(String(localized: "soul.tap_avatar_hint"))
                        .font(.caption2)
                        .foregroundStyle(.purple.opacity(0.7))
                }

                Spacer()
            }

            // Completeness Bar
            if let profile = profile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "soul.completeness"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(profile.profileCompleteness * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * profile.profileCompleteness, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "soul.progress"))
                .font(.headline)

            HStack(spacing: 12) {
                StatBox(
                    title: String(localized: "soul.stat.interviews"),
                    value: "\(profile?.interviewCount ?? 0)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .blue
                )

                StatBox(
                    title: String(localized: "soul.stat.assessments"),
                    value: "\(profile?.assessmentCount ?? 0)",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "soul.actions"))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionCard(
                    title: String(localized: "soul.action.interview"),
                    subtitle: String(localized: "soul.action.interview.desc"),
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                ) {
                    selectedInterviewType = .periodic
                    showingInterview = true
                }

                ActionCard(
                    title: String(localized: "soul.action.mbti"),
                    subtitle: profile?.mbtiType ?? String(localized: "soul.action.mbti.desc"),
                    icon: "person.crop.circle.badge.questionmark",
                    color: .purple
                ) {
                    showingAssessments = true
                }

                ActionCard(
                    title: String(localized: "soul.action.deepdive"),
                    subtitle: String(localized: "soul.action.deepdive.desc"),
                    icon: "magnifyingglass",
                    color: .orange
                ) {
                    selectedInterviewType = .deepDive
                    showingInterview = true
                }

                ActionCard(
                    title: String(localized: "soul.action.values"),
                    subtitle: String(localized: "soul.action.values.desc"),
                    icon: "star.fill",
                    color: .yellow
                ) {
                    showingAssessments = true
                }

                ActionCard(
                    title: String(localized: "soul.action.voice"),
                    subtitle: voiceCloneSubtitle,
                    icon: "waveform.circle",
                    color: .cyan
                ) {
                    showingVoiceClone = true
                }

                ActionCard(
                    title: String(localized: "soul.action.writing"),
                    subtitle: writingStyleSubtitle,
                    icon: "pencil.line",
                    color: .mint
                ) {
                    showingWritingStyle = true
                }

                ActionCard(
                    title: String(localized: "soul.action.avatar"),
                    subtitle: avatarSubtitle,
                    icon: "person.crop.square",
                    color: .indigo
                ) {
                    showingAvatar = true
                }

                ActionCard(
                    title: String(localized: "soul.action.digitalself"),
                    subtitle: digitalSelfSubtitle,
                    icon: "person.crop.circle.badge.checkmark",
                    color: .pink,
                    isPremiumFeature: !StoreService.shared.canUseDigitalSelf
                ) {
                    showingDigitalSelf = true
                }
            }
        }
    }

    private var digitalSelfSubtitle: String {
        guard let config = digitalSelfConfig else {
            return String(localized: "soul.action.digitalself.desc")
        }
        switch config.currentStatus {
        case .notReady:
            return String(localized: "soul.action.digitalself.desc")
        case .ready:
            return String(localized: "soul.action.digitalself.ready")
        case .active:
            return String(localized: "soul.action.digitalself.active")
        case .paused:
            return String(localized: "soul.action.digitalself.paused")
        }
    }

    private var avatarSubtitle: String {
        guard let avatarProfile = avatarProfile else {
            return String(localized: "soul.action.avatar.desc")
        }
        if avatarProfile.hasStylizedVersion {
            return String(localized: "soul.action.avatar.stylized")
        } else if avatarProfile.hasPhoto {
            return String(localized: "soul.action.avatar.ready")
        } else {
            return String(localized: "soul.action.avatar.desc")
        }
    }

    private var writingStyleSubtitle: String {
        guard let writingProfile = writingProfile else {
            return String(localized: "soul.action.writing.desc")
        }
        switch writingProfile.status {
        case .notAnalyzed:
            return String(localized: "soul.action.writing.desc")
        case .analyzing:
            return String(localized: "soul.action.writing.analyzing")
        case .ready:
            return String(localized: "soul.action.writing.ready")
        case .failed:
            return String(localized: "soul.action.writing.failed")
        }
    }

    private var voiceCloneSubtitle: String {
        guard let voiceProfile = voiceProfile else {
            return String(localized: "soul.action.voice.desc")
        }
        switch voiceProfile.status {
        case .notStarted:
            return String(localized: "soul.action.voice.desc")
        case .collecting:
            return String(localized: "soul.action.voice.collecting")
        case .training:
            return String(localized: "soul.action.voice.training")
        case .ready:
            return String(localized: "soul.action.voice.ready")
        case .failed:
            return String(localized: "soul.action.voice.failed")
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "soul.recent"))
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(completedInterviews.prefix(3)) { interview in
                    ActivityRow(
                        icon: interview.type.icon,
                        title: interview.type.label,
                        subtitle: interview.topic?.label,
                        date: interview.completedAt ?? interview.createdAt,
                        color: .blue
                    )
                }

                ForEach(completedAssessments.prefix(3)) { assessment in
                    ActivityRow(
                        icon: assessment.type.icon,
                        title: assessment.type.label,
                        subtitle: assessment.resultCode,
                        date: assessment.completedAt ?? assessment.createdAt,
                        color: .green
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let profile = SoulProfile()
            modelContext.insert(profile)
            try? modelContext.save()
        }
    }
}

// MARK: - Supporting Views

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

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
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isPremiumFeature: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)

                    Spacer()

                    if isPremiumFeature {
                        Text("PRO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let date: Date
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(date, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SoulTabView()
        .modelContainer(for: [SoulProfile.self, InterviewSession.self, AssessmentResult.self, VoiceProfile.self, WritingStyleProfile.self, AvatarProfile.self, DigitalSelfConfig.self, Contact.self, Message.self], inMemory: true)
}
