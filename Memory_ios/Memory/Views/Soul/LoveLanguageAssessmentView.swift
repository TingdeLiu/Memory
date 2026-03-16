import SwiftUI
import SwiftData

struct LoveLanguageAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SoulProfile]

    @State private var currentQuestionIndex = 0
    @State private var answers: [Bool] = []
    @State private var showingResult = false
    @State private var result: AssessmentResult?
    @State private var isProcessing = false

    private var profile: SoulProfile? { profiles.first }
    private let questions = LoveLanguageQuestions.questions

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                if showingResult, let result = result {
                    resultView(result: result)
                } else {
                    questionView
                }
            }
            .navigationTitle(String(localized: "assessment.lovelanguage"))
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
                    .fill(Color.pink)
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

            Text(questions[currentQuestionIndex].text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 16) {
                LoveOptionButton(
                    text: questions[currentQuestionIndex].optionA.0,
                    language: questions[currentQuestionIndex].optionA.1
                ) {
                    selectAnswer(true)
                }

                LoveOptionButton(
                    text: questions[currentQuestionIndex].optionB.0,
                    language: questions[currentQuestionIndex].optionB.1
                ) {
                    selectAnswer(false)
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

    private func resultView(result: AssessmentResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top Languages
                VStack(spacing: 16) {
                    Text(String(localized: "lovelanguage.your_languages"))
                        .font(.headline)

                    ForEach(result.topLoveLanguages, id: \.self) { language in
                        HStack {
                            Image(systemName: language.icon)
                                .font(.title2)
                                .foregroundStyle(.pink)
                                .frame(width: 40)

                            VStack(alignment: .leading) {
                                Text(language.label)
                                    .font(.headline)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // All Languages Description
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "lovelanguage.all_languages"))
                        .font(.headline)

                    ForEach(LoveLanguage.allCases, id: \.self) { language in
                        HStack(alignment: .top) {
                            Image(systemName: language.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading) {
                                Text(language.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

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

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "common.done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func selectAnswer(_ answer: Bool) {
        answers.append(answer)
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
        let topLanguages = LoveLanguageQuestions.calculateResult(answers: answers)
        let resultCode = topLanguages.map { $0.rawValue }.joined(separator: ",")

        let assessment = AssessmentResult(type: .loveLanguage)
        assessment.setAnswers(answers)
        assessment.complete(resultCode: resultCode)

        modelContext.insert(assessment)
        try? modelContext.save()

        result = assessment
        showingResult = true

        Task {
            isProcessing = true
            if let profile = profile {
                await SoulService.shared.processLoveLanguageResult(
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

private struct LoveOptionButton: View {
    let text: String
    let language: LoveLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: language.icon)
                    .foregroundStyle(.pink)

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding()
            .background(Color.pink.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoveLanguageAssessmentView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
