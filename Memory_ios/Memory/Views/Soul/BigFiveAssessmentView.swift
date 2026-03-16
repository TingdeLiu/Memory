import SwiftUI
import SwiftData

struct BigFiveAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SoulProfile]

    @State private var currentQuestionIndex = 0
    @State private var answers: [Int] = []  // 1-5 scale
    @State private var showingResult = false
    @State private var result: AssessmentResult?
    @State private var scores: BigFiveScores?
    @State private var isAnalyzing = false

    private var profile: SoulProfile? { profiles.first }

    // Big Five questions - BFI-44
    private let questions: [(String, BigFiveDimension, Bool)] = [
        (String(localized: "bigfive.q.1"), .extraversion, false),
        (String(localized: "bigfive.q.2"), .agreeableness, true),
        (String(localized: "bigfive.q.3"), .conscientiousness, false),
        (String(localized: "bigfive.q.4"), .neuroticism, false),
        (String(localized: "bigfive.q.5"), .openness, false),
        (String(localized: "bigfive.q.6"), .extraversion, true),
        (String(localized: "bigfive.q.7"), .agreeableness, false),
        (String(localized: "bigfive.q.8"), .conscientiousness, true),
        (String(localized: "bigfive.q.9"), .neuroticism, true),
        (String(localized: "bigfive.q.10"), .openness, false),
        (String(localized: "bigfive.q.11"), .extraversion, false),
        (String(localized: "bigfive.q.12"), .agreeableness, true),
        (String(localized: "bigfive.q.13"), .conscientiousness, false),
        (String(localized: "bigfive.q.14"), .neuroticism, false),
        (String(localized: "bigfive.q.15"), .openness, false),
        (String(localized: "bigfive.q.16"), .extraversion, false),
        (String(localized: "bigfive.q.17"), .agreeableness, false),
        (String(localized: "bigfive.q.18"), .conscientiousness, true),
        (String(localized: "bigfive.q.19"), .neuroticism, false),
        (String(localized: "bigfive.q.20"), .openness, false),
        (String(localized: "bigfive.q.21"), .extraversion, true),
        (String(localized: "bigfive.q.22"), .agreeableness, false),
        (String(localized: "bigfive.q.23"), .conscientiousness, true),
        (String(localized: "bigfive.q.24"), .neuroticism, true),
        (String(localized: "bigfive.q.25"), .openness, false),
        (String(localized: "bigfive.q.26"), .extraversion, false),
        (String(localized: "bigfive.q.27"), .agreeableness, true),
        (String(localized: "bigfive.q.28"), .conscientiousness, false),
        (String(localized: "bigfive.q.29"), .neuroticism, false),
        (String(localized: "bigfive.q.30"), .openness, false),
        (String(localized: "bigfive.q.31"), .extraversion, true),
        (String(localized: "bigfive.q.32"), .agreeableness, false),
        (String(localized: "bigfive.q.33"), .conscientiousness, false),
        (String(localized: "bigfive.q.34"), .neuroticism, true),
        (String(localized: "bigfive.q.35"), .openness, true),
        (String(localized: "bigfive.q.36"), .extraversion, false),
        (String(localized: "bigfive.q.37"), .agreeableness, true),
        (String(localized: "bigfive.q.38"), .conscientiousness, false),
        (String(localized: "bigfive.q.39"), .neuroticism, false),
        (String(localized: "bigfive.q.40"), .openness, false),
        (String(localized: "bigfive.q.41"), .openness, true),
        (String(localized: "bigfive.q.42"), .agreeableness, false),
        (String(localized: "bigfive.q.43"), .conscientiousness, true),
        (String(localized: "bigfive.q.44"), .openness, false)
    ]

    enum BigFiveDimension {
        case openness, conscientiousness, extraversion, agreeableness, neuroticism
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                if showingResult, let scores = scores {
                    resultView(scores: scores)
                } else {
                    questionView
                }
            }
            .navigationTitle(String(localized: "assessment.bigfive"))
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
                    .fill(Color.blue)
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

            // 5-point scale
            VStack(spacing: 16) {
                HStack {
                    Text(String(localized: "bigfive.disagree"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "bigfive.agree"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            selectAnswer(value)
                        } label: {
                            Text("\(value)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(value <= 2 ? .red : (value >= 4 ? .green : .orange))
                                .frame(width: 50, height: 50)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
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

    private func resultView(scores: BigFiveScores) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                // Radar Chart Display
                VStack(spacing: 24) {
                    Text(String(localized: "bigfive.your_profile"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    BigFiveRadarChart(scores: scores, size: 220)
                        .padding(.vertical, 40)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // AI Analysis Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(String(localized: "assessment.ai_analysis"))
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.blue)

                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text(String(localized: "assessment.generating"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let analysis = result?.analysis {
                        Text(analysis)
                            .font(.body)
                            .lineSpacing(4)
                    } else {
                        Text("Personalized analysis will appear here...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )

                // Descriptions
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "bigfive.what_means"))
                        .font(.headline)

                    DimensionDescription(
                        title: String(localized: "bigfive.openness"),
                        description: String(localized: "bigfive.openness.desc"),
                        level: levelText(scores.openness)
                    )

                    DimensionDescription(
                        title: String(localized: "bigfive.conscientiousness"),
                        description: String(localized: "bigfive.conscientiousness.desc"),
                        level: levelText(scores.conscientiousness)
                    )

                    DimensionDescription(
                        title: String(localized: "bigfive.extraversion"),
                        description: String(localized: "bigfive.extraversion.desc"),
                        level: levelText(scores.extraversion)
                    )

                    DimensionDescription(
                        title: String(localized: "bigfive.agreeableness"),
                        description: String(localized: "bigfive.agreeableness.desc"),
                        level: levelText(scores.agreeableness)
                    )

                    DimensionDescription(
                        title: String(localized: "bigfive.neuroticism"),
                        description: String(localized: "bigfive.neuroticism.desc"),
                        level: levelText(scores.neuroticism)
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "common.done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func levelText(_ value: Double) -> String {
        if value >= 0.7 {
            return String(localized: "bigfive.level.high")
        } else if value <= 0.3 {
            return String(localized: "bigfive.level.low")
        } else {
            return String(localized: "bigfive.level.moderate")
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
        // Calculate scores for each dimension (average of questions, normalized to 0-1)
        var dimensionScores: [BigFiveDimension: [Double]] = [:]
        
        for (index, answer) in answers.enumerated() {
            guard index < questions.count else { break }
            let (_, dimension, isReverse) = questions[index]
            
            // Adjust for reverse scoring (1->5, 2->4, 3->3, 4->2, 5->1)
            let finalValue = isReverse ? Double(6 - answer) : Double(answer)
            dimensionScores[dimension, default: []].append(finalValue)
        }

        func average(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return 0.5 }
            // Normalize to 0-1 range (score is 1-5, so (sum/count - 1) / 4)
            let avg = values.reduce(0, +) / Double(values.count)
            return (avg - 1) / 4.0
        }

        let calculatedScores = BigFiveScores(
            O: average(dimensionScores[.openness] ?? []),
            C: average(dimensionScores[.conscientiousness] ?? []),
            E: average(dimensionScores[.extraversion] ?? []),
            A: average(dimensionScores[.agreeableness] ?? []),
            N: average(dimensionScores[.neuroticism] ?? [])
        )

        let scoresData = try? JSONEncoder().encode(calculatedScores)

        let assessment = AssessmentResult(type: .bigFive)
        assessment.setAnswers(answers)
        assessment.complete(resultCode: nil, scores: scoresData)

        modelContext.insert(assessment)

        if let profile = profile {
            profile.bigFiveScores = scoresData
            profile.bigFiveDate = Date()
            profile.assessmentCount += 1
            profile.updateCompleteness()
        }

        try? modelContext.save()

        scores = calculatedScores
        result = assessment
        showingResult = true

        Task {
            isAnalyzing = true
            if let profile = profile {
                await SoulService.shared.processBigFiveResult(
                    profile: profile,
                    result: assessment,
                    aiService: AIService(),
                    context: modelContext
                )
            }
            isAnalyzing = false
        }
    }
}

private struct DimensionBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct DimensionDescription: View {
    let title: String
    let description: String
    let level: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(level)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BigFiveAssessmentView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
