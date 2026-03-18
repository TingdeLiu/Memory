import SwiftUI
import SwiftData

struct MBTIAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SoulProfile]

    @State private var currentQuestionIndex = 0
    @State private var answers: [Bool] = []  // true = A, false = B
    @State private var showingResult = false
    @State private var result: AssessmentResult?
    @State private var isProcessing = false

    private var profile: SoulProfile? { profiles.first }
    private let questions = MBTIQuestions.questions

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress
                progressBar

                if showingResult, let result = result {
                    resultView(result: result)
                } else {
                    questionView
                }
            }
            .navigationTitle("MBTI")
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

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))

                Rectangle()
                    .fill(Color.purple)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut, value: progress)
            }
        }
        .frame(height: 4)
    }

    private var progress: Double {
        Double(currentQuestionIndex) / Double(questions.count)
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Question Number
            Text(String(localized: "assessment.question \(currentQuestionIndex + 1) \(questions.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Question Text
            Text(questions[currentQuestionIndex].text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Options
            VStack(spacing: 16) {
                OptionButton(
                    text: questions[currentQuestionIndex].optionA,
                    color: .purple
                ) {
                    selectAnswer(true)
                }

                OptionButton(
                    text: questions[currentQuestionIndex].optionB,
                    color: .blue
                ) {
                    selectAnswer(false)
                }
            }
            .padding(.horizontal)

            // Back button
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

    // MARK: - Result View

    private func resultView(result: AssessmentResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Result Badge
                if let mbtiCode = result.resultCode, let mbti = MBTIType(rawValue: mbtiCode) {
                    VStack(spacing: 12) {
                        Text(mbtiCode)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(mbti.nickname)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(mbti.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Dimension Breakdown
                    dimensionBreakdown(mbti: mbti)
                }

                // AI Analysis
                if let analysis = result.analysis {
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

                // Done Button
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "common.done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func dimensionBreakdown(mbti: MBTIType) -> some View {
        VStack(spacing: 12) {
            Text(String(localized: "assessment.dimensions"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            DimensionRow(
                leftLabel: "E",
                leftDescription: String(localized: "mbti.extraversion"),
                rightLabel: "I",
                rightDescription: String(localized: "mbti.introversion"),
                isLeft: !mbti.isIntrovert
            )

            DimensionRow(
                leftLabel: "S",
                leftDescription: String(localized: "mbti.sensing"),
                rightLabel: "N",
                rightDescription: String(localized: "mbti.intuition"),
                isLeft: !mbti.isIntuitive
            )

            DimensionRow(
                leftLabel: "T",
                leftDescription: String(localized: "mbti.thinking"),
                rightLabel: "F",
                rightDescription: String(localized: "mbti.feeling"),
                isLeft: mbti.isThinking
            )

            DimensionRow(
                leftLabel: "J",
                leftDescription: String(localized: "mbti.judging"),
                rightLabel: "P",
                rightDescription: String(localized: "mbti.perceiving"),
                isLeft: mbti.isJudging
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func selectAnswer(_ answer: Bool) {
        answers.append(answer)

        if currentQuestionIndex < questions.count - 1 {
            withAnimation {
                currentQuestionIndex += 1
            }
        } else {
            calculateResult()
        }
    }

    private func goBack() {
        guard currentQuestionIndex > 0 else { return }
        answers.removeLast()
        withAnimation {
            currentQuestionIndex -= 1
        }
    }

    private func calculateResult() {
        guard let mbtiCode = MBTIQuestions.calculateType(answers: answers) else { return }

        let assessment = AssessmentResult(type: .mbti)
        assessment.setAnswers(answers)
        assessment.complete(resultCode: mbtiCode)

        modelContext.insert(assessment)
        try? modelContext.save()

        result = assessment
        showingResult = true

        // Process with AI
        Task {
            isProcessing = true
            if let profile = profile {
                await SoulService.shared.processMBTIResult(
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

// MARK: - Option Button

private struct OptionButton: View {
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dimension Row

private struct DimensionRow: View {
    let leftLabel: String
    let leftDescription: String
    let rightLabel: String
    let rightDescription: String
    let isLeft: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(leftLabel)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(isLeft ? .purple : .secondary)
                Text(leftDescription)
                    .font(.caption)
                    .foregroundStyle(isLeft ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 24)

                Circle()
                    .fill(Color.purple)
                    .frame(width: 20, height: 20)
                    .offset(x: isLeft ? -15 : 15)
            }

            VStack(alignment: .trailing) {
                Text(rightLabel)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(!isLeft ? .purple : .secondary)
                Text(rightDescription)
                    .font(.caption)
                    .foregroundStyle(!isLeft ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    MBTIAssessmentView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
