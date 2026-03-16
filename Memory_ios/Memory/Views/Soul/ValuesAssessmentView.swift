import SwiftUI
import SwiftData

struct ValuesAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SoulProfile]

    @State private var currentQuestionIndex = 0
    @State private var answers: [Int] = []  // 1-6 scale
    @State private var showingResult = false
    @State private var result: AssessmentResult?
    @State private var schwartzScores: SchwartzValuesScores?
    @State private var isProcessing = false

    private var profile: SoulProfile? { profiles.first }

    // Schwartz PVQ-40 Dimensions
    enum SchwartzDimension {
        case power, achievement, hedonism, stimulation, selfDirection, universalism, benevolence, tradition, conformity, security
    }

    private let questions: [(String, SchwartzDimension)] = [
        (String(localized: "values.q.1"), .selfDirection),
        (String(localized: "values.q.2"), .power),
        (String(localized: "values.q.3"), .universalism),
        (String(localized: "values.q.4"), .achievement),
        (String(localized: "values.q.5"), .security),
        (String(localized: "values.q.6"), .stimulation),
        (String(localized: "values.q.7"), .conformity),
        (String(localized: "values.q.8"), .universalism),
        (String(localized: "values.q.9"), .tradition),
        (String(localized: "values.q.10"), .hedonism),
        (String(localized: "values.q.11"), .selfDirection),
        (String(localized: "values.q.12"), .benevolence),
        (String(localized: "values.q.13"), .achievement),
        (String(localized: "values.q.14"), .security),
        (String(localized: "values.q.15"), .stimulation),
        (String(localized: "values.q.16"), .conformity),
        (String(localized: "values.q.17"), .power),
        (String(localized: "values.q.18"), .benevolence),
        (String(localized: "values.q.19"), .universalism),
        (String(localized: "values.q.20"), .tradition),
        (String(localized: "values.q.21"), .security),
        (String(localized: "values.q.22"), .selfDirection),
        (String(localized: "values.q.23"), .universalism),
        (String(localized: "values.q.24"), .achievement),
        (String(localized: "values.q.25"), .tradition),
        (String(localized: "values.q.26"), .hedonism),
        (String(localized: "values.q.27"), .benevolence),
        (String(localized: "values.q.28"), .conformity),
        (String(localized: "values.q.29"), .universalism),
        (String(localized: "values.q.30"), .stimulation),
        (String(localized: "values.q.31"), .security),
        (String(localized: "values.q.32"), .achievement),
        (String(localized: "values.q.33"), .benevolence),
        (String(localized: "values.q.34"), .selfDirection),
        (String(localized: "values.q.35"), .security),
        (String(localized: "values.q.36"), .conformity),
        (String(localized: "values.q.37"), .hedonism),
        (String(localized: "values.q.38"), .tradition),
        (String(localized: "values.q.39"), .power),
        (String(localized: "values.q.40"), .universalism)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                if showingResult, let scores = schwartzScores {
                    resultView(scores: scores)
                } else {
                    questionView
                }
            }
            .navigationTitle(String(localized: "assessment.values"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: geometry.size.width * Double(currentQuestionIndex) / Double(questions.count))
                    .animation(.easeInOut, value: currentQuestionIndex)
            }
        }
        .frame(height: 4)
    }

    private var questionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(String(localized: "assessment.question \(currentQuestionIndex + 1) \(questions.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(questions[currentQuestionIndex].0)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // 6-point scale (PVQ standard)
            VStack(spacing: 12) {
                ForEach([
                    (6, "values.similarity.very_much"),
                    (5, "values.similarity.like_me"),
                    (4, "values.similarity.somewhat"),
                    (3, "values.similarity.little"),
                    (2, "values.similarity.not_like_me"),
                    (1, "values.similarity.not_at_all")
                ], id: \.0) { value, labelKey in
                    Button {
                        selectAnswer(value)
                    } label: {
                        Text(String(localized: .init(labelKey)))
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            if currentQuestionIndex > 0 {
                Button {
                    goBack()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(String(localized: "assessment.previous"))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    private func resultView(scores: SchwartzValuesScores) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top Values
                VStack(spacing: 16) {
                    Text(String(localized: "values.your_values"))
                        .font(.headline)

                    ForEach(Array(scores.sortedDimensions.prefix(5).enumerated()), id: \.element.0) { index, item in
                        HStack {
                            Text("\(index + 1)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .frame(width: 40)

                            Text(item.0)
                                .font(.headline)

                            Spacer()
                            
                            Text("\(Int(item.1 * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // AI Analysis
                if let analysis = result?.analysis {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(String(localized: "assessment.ai_analysis"), systemImage: "sparkles")
                            .font(.headline)

                        Text(analysis)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isProcessing {
                    HStack {
                        ProgressView()
                        Text(String(localized: "assessment.generating"))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "common.done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func selectAnswer(_ value: Int) {
        answers.append(value)
        if currentQuestionIndex < questions.count - 1 {
            withAnimation { currentQuestionIndex += 1 }
        } else {
            calculateResult()
        }
    }

    private func goBack() {
        guard currentQuestionIndex > 0 else { return }
        answers.removeLast()
        withAnimation { currentQuestionIndex -= 1 }
    }

    private func calculateResult() {
        var dimensionScores: [SchwartzDimension: [Int]] = [:]
        for (index, answer) in answers.enumerated() {
            guard index < questions.count else { break }
            let dimension = questions[index].1
            dimensionScores[dimension, default: []].append(answer)
        }

        func average(_ values: [Int]) -> Double {
            guard !values.isEmpty else { return 0.5 }
            // Normalize 1-6 to 0-1
            return Double(values.reduce(0, +)) / Double(values.count * 6)
        }

        let calculatedScores = SchwartzValuesScores(
            power: average(dimensionScores[.power] ?? []),
            achievement: average(dimensionScores[.achievement] ?? []),
            hedonism: average(dimensionScores[.hedonism] ?? []),
            stimulation: average(dimensionScores[.stimulation] ?? []),
            selfDirection: average(dimensionScores[.selfDirection] ?? []),
            universalism: average(dimensionScores[.universalism] ?? []),
            benevolence: average(dimensionScores[.benevolence] ?? []),
            tradition: average(dimensionScores[.tradition] ?? []),
            conformity: average(dimensionScores[.conformity] ?? []),
            security: average(dimensionScores[.security] ?? [])
        )

        let scoresData = try? JSONEncoder().encode(calculatedScores)

        let assessment = AssessmentResult(type: .values)
        assessment.setAnswers(answers)
        assessment.complete(resultCode: nil, scores: scoresData)

        modelContext.insert(assessment)

        if let profile = profile {
            profile.schwartzValuesScores = scoresData
            profile.valuesDate = Date()
            profile.assessmentCount += 1
            profile.updateCompleteness()
        }

        try? modelContext.save()

        schwartzScores = calculatedScores
        result = assessment
        showingResult = true

        Task {
            isProcessing = true
            if let profile = profile {
                await SoulService.shared.processValuesResult(
                    profile: profile,
                    result: assessment,
                    aiService: AIService(),
                    context: modelContext
                )
            }
            isProcessing = false
        }
    }
}

#Preview {
    ValuesAssessmentView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
