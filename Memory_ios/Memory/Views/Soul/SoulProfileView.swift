import SwiftUI
import SwiftData

struct SoulProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SoulProfileViewModel?
    private let profile: SoulProfile

    @Query private var memories: [MemoryEntry]

    init(profile: SoulProfile) {
        self.profile = profile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let vm = viewModel {
                    VStack(spacing: 24) {
                        // Header Card
                        headerCard

                        // Basic Info
                        if vm.isEditing || vm.hasBasicInfo {
                            basicInfoSection
                        }

                        // Personality Section
                        if let mbti = vm.profile.mbtiType {
                            personalitySection(mbti: mbti)
                        }

                        // Values Section
                        if !vm.profile.valuesRanking.isEmpty {
                            valuesSection
                        }

                        // Love Languages Section
                        if !vm.profile.loveLanguages.isEmpty {
                            loveLanguagesSection
                        }

                        // AI Insights
                        if vm.hasAIInsights {
                            aiInsightsSection
                        }

                        // Analyze Button
                        if !memories.isEmpty {
                            analyzeButton
                        }
                    }
                    .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .navigationTitle(String(localized: "soul.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel?.isEditing == true ? String(localized: "common.save") : String(localized: "common.edit")) {
                        viewModel?.toggleEditing()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingEditSheet ?? false },
                set: { viewModel?.showingEditSheet = $0 }
            )) {
                if let vm = viewModel {
                    ProfileEditSheet(profile: vm.profile)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SoulProfileViewModel(profile: profile, modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                if let nickname = viewModel?.profile.nickname ?? profile.nickname, let firstChar = nickname.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }

            // Name and Age
            VStack(spacing: 4) {
                if viewModel?.isEditing == true {
                    TextField(String(localized: "soul.nickname.placeholder"), text: Binding(
                        get: { viewModel?.profile.nickname ?? "" },
                        set: { viewModel?.profile.nickname = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                } else {
                    Text(viewModel?.profile.displayName ?? profile.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                if let age = viewModel?.profile.age ?? profile.age {
                    Text(String(localized: "soul.age \(age)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // MBTI Badge
            if let mbti = viewModel?.profile.mbtiType ?? profile.mbtiType {
                HStack {
                    Text(mbti)
                        .font(.headline)
                        .fontWeight(.bold)

                    if let type = MBTIType(rawValue: mbti) {
                        Text("・")
                        Text(type.nickname)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
            }

            // Completeness & Soul Level
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "soul.completeness"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((viewModel?.profile.profileCompleteness ?? profile.profileCompleteness) * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                ProgressView(value: viewModel?.profile.profileCompleteness ?? profile.profileCompleteness)
                    .tint(.purple)

                // Gamified Level Badge
                HStack(spacing: 8) {
                    Image(systemName: viewModel?.profile.currentLevel.icon ?? profile.currentLevel.icon)
                        .foregroundStyle(.purple)
                        .symbolEffect(.pulse)

                    Text(viewModel?.profile.currentLevel.title ?? profile.currentLevel.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))

        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "soul.basic_info"), icon: "person.text.rectangle")

            VStack(spacing: 12) {
                if viewModel?.isEditing == true {
                    InfoEditRow(
                        label: String(localized: "soul.birthday"),
                        icon: "gift",
                        date: Binding(
                            get: { viewModel?.profile.birthday },
                            set: { viewModel?.profile.birthday = $0 }
                        )
                    )

                    InfoEditRow(
                        label: String(localized: "soul.birthplace"),
                        icon: "mappin",
                        text: Binding(
                            get: { viewModel?.profile.birthplace ?? "" },
                            set: { viewModel?.profile.birthplace = $0.isEmpty ? nil : $0 }
                        )
                    )

                    InfoEditRow(
                        label: String(localized: "soul.current_city"),
                        icon: "building.2",
                        text: Binding(
                            get: { viewModel?.profile.currentCity ?? "" },
                            set: { viewModel?.profile.currentCity = $0.isEmpty ? nil : $0 }
                        )
                    )
                } else {
                    if let birthday = viewModel?.profile.birthday ?? profile.birthday {
                        InfoRow(label: String(localized: "soul.birthday"), value: birthday.formatted(date: .long, time: .omitted), icon: "gift")
                    }
                    if let birthplace = viewModel?.profile.birthplace ?? profile.birthplace {
                        InfoRow(label: String(localized: "soul.birthplace"), value: birthplace, icon: "mappin")
                    }
                    if let city = viewModel?.profile.currentCity ?? profile.currentCity {
                        InfoRow(label: String(localized: "soul.current_city"), value: city, icon: "building.2")
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Personality Section

    private func personalitySection(mbti: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "soul.personality"), icon: "brain.head.profile")

            if let type = MBTIType(rawValue: mbti) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(mbti)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)

                        Text(type.nickname)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(type.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if let date = viewModel?.profile.mbtiDate ?? profile.mbtiDate {
                        Text(String(localized: "soul.tested_on \(date.formatted(date: .abbreviated, time: .omitted))"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Values Section

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "soul.values"), icon: "star.fill")

            VStack(alignment: .leading, spacing: 8) {
                let values = viewModel?.profile.valuesRanking ?? profile.valuesRanking
                ForEach(Array(values.prefix(5).enumerated()), id: \.element) { index, valueStr in
                    if let value = CoreValue(rawValue: valueStr) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.orange)
                                .clipShape(Circle())

                            Image(systemName: value.icon)
                                .foregroundStyle(.orange)

                            Text(value.label)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Love Languages Section

    private var loveLanguagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "soul.love_languages"), icon: "heart.fill")

            VStack(alignment: .leading, spacing: 8) {
                let languages = viewModel?.profile.loveLanguages ?? profile.loveLanguages
                ForEach(languages, id: \.self) { langStr in
                    if let lang = LoveLanguage(rawValue: langStr) {
                        HStack {
                            Image(systemName: lang.icon)
                                .foregroundStyle(.pink)
                                .frame(width: 24)

                            Text(lang.label)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "soul.ai_insights"), icon: "sparkles")

            VStack(spacing: 12) {
                if let insights = viewModel?.profile.personalityInsights ?? profile.personalityInsights {
                    InsightCard(title: String(localized: "soul.personality_insights"), content: insights)
                }

                if let story = viewModel?.profile.lifeStory ?? profile.lifeStory {
                    InsightCard(title: String(localized: "soul.life_story"), content: story)
                }

                if let patterns = viewModel?.profile.emotionalPatterns ?? profile.emotionalPatterns {
                    InsightCard(title: String(localized: "soul.emotional_patterns"), content: patterns)
                }

                if let core = viewModel?.profile.coreMemories ?? profile.coreMemories {
                    InsightCard(title: String(localized: "soul.core_memories"), content: core)
                }
            }

            if let date = viewModel?.profile.lastMemoryAnalysisDate ?? profile.lastMemoryAnalysisDate {
                Text(String(localized: "soul.analyzed_on \(date.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button {
            Task {
                await viewModel?.analyzeMemories(memories: memories)
            }
        } label: {
            HStack {
                if viewModel?.isAnalyzing == true {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel?.isAnalyzing == true ? String(localized: "soul.analyzing") : String(localized: "soul.analyze_memories"))
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
        .disabled(viewModel?.isAnalyzing ?? false)
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct InfoEditRow: View {
    let label: String
    let icon: String
    var date: Binding<Date?>?
    var text: Binding<String>?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            if let dateBinding = date {
                DatePicker("", selection: Binding(
                    get: { dateBinding.wrappedValue ?? Date() },
                    set: { dateBinding.wrappedValue = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
            } else if let textBinding = text {
                TextField("", text: textBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
            }
        }
    }
}

private struct InsightCard: View {
    let title: String
    let content: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: SoulProfile

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "soul.basic_info")) {
                    TextField(String(localized: "soul.nickname"), text: Binding(
                        get: { profile.nickname ?? "" },
                        set: { profile.nickname = $0.isEmpty ? nil : $0 }
                    ))

                    DatePicker(String(localized: "soul.birthday"), selection: Binding(
                        get: { profile.birthday ?? Date() },
                        set: { profile.birthday = $0 }
                    ), displayedComponents: .date)

                    TextField(String(localized: "soul.birthplace"), text: Binding(
                        get: { profile.birthplace ?? "" },
                        set: { profile.birthplace = $0.isEmpty ? nil : $0 }
                    ))

                    TextField(String(localized: "soul.current_city"), text: Binding(
                        get: { profile.currentCity ?? "" },
                        set: { profile.currentCity = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle(String(localized: "soul.edit_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SoulProfileView(profile: SoulProfile())
        .modelContainer(for: [SoulProfile.self, MemoryEntry.self], inMemory: true)
}
