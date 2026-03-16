import SwiftUI
import SwiftData

struct AssessmentListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var assessments: [AssessmentResult]
    @Query private var profiles: [SoulProfile]

    @State private var selectedAssessment: AssessmentType?

    private var profile: SoulProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AssessmentType.allCases, id: \.self) { type in
                        AssessmentRow(
                            type: type,
                            lastResult: lastResult(for: type),
                            profile: profile
                        ) {
                            selectedAssessment = type
                        }
                    }
                } header: {
                    Text(String(localized: "assessment.available"))
                } footer: {
                    Text(String(localized: "assessment.footer"))
                }

                if !completedAssessments.isEmpty {
                    Section(String(localized: "assessment.history")) {
                        ForEach(completedAssessments.prefix(10)) { result in
                            HistoryRow(result: result)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "assessment.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedAssessment) { type in
                assessmentView(for: type)
            }
        }
    }

    private var completedAssessments: [AssessmentResult] {
        assessments
            .filter { $0.isComplete }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    private func lastResult(for type: AssessmentType) -> AssessmentResult? {
        assessments
            .filter { $0.type == type && $0.isComplete }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
            .first
    }

    @ViewBuilder
    private func assessmentView(for type: AssessmentType) -> some View {
        switch type {
        case .mbti:
            MBTIAssessmentView()
        case .bigFive:
            BigFiveAssessmentView()
        case .loveLanguage:
            LoveLanguageAssessmentView()
        case .values:
            ValuesAssessmentView()
        case .legacy:
            LegacyAssessmentView()
        }
    }
}

// MARK: - Assessment Row

private struct AssessmentRow: View {
    let type: AssessmentType
    let lastResult: AssessmentResult?
    let profile: SoulProfile?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.label)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let result = currentResult {
                        HStack {
                            Text(result)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(iconColor)

                            if let date = lastResult?.completedAt {
                                Text("・")
                                    .foregroundStyle(.secondary)
                                Text(date, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                VStack {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)

                    Text(String(localized: "assessment.minutes \(type.estimatedMinutes)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch type {
        case .mbti: return .purple
        case .bigFive: return .blue
        case .loveLanguage: return .pink
        case .values: return .orange
        case .legacy: return .teal
        }
    }

    private var currentResult: String? {
        switch type {
        case .mbti:
            return profile?.mbtiType
        case .bigFive:
            return nil  // Too complex to show inline
        case .loveLanguage:
            if let langs = profile?.loveLanguages, !langs.isEmpty {
                return langs.prefix(2).compactMap { LoveLanguage(rawValue: $0)?.label }.joined(separator: ", ")
            }
            return nil
        case .values:
            if let _ = profile?.schwartzValuesScores {
                return String(localized: "assessment.complete")
            }
            if let values = profile?.valuesRanking, !values.isEmpty {
                return values.prefix(3).compactMap { CoreValue(rawValue: $0)?.label }.joined(separator: ", ")
            }
            return nil
        case .legacy:
            if lastResult != nil {
                return String(localized: "assessment.complete")
            }
            return nil
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let result: AssessmentResult

    var body: some View {
        HStack {
            Image(systemName: result.type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(result.type.label)
                    .font(.subheadline)

                if let code = result.resultCode {
                    Text(code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let date = result.completedAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Assessment Type Identifiable

extension AssessmentType: Identifiable {
    var id: String { rawValue }
}

#Preview {
    AssessmentListView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
