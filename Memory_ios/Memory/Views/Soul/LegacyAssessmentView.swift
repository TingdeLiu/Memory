import SwiftUI
import SwiftData

struct LegacyAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SoulProfile]

    @State private var currentQuestionIndex = 0
    @State private var answers: [String] = ["", "", "", "", ""]
    @State private var showingResult = false
    @State private var result: AssessmentResult?
    @State private var isSaving = false
    @State private var isAnalyzing = false

    private var profile: SoulProfile? { profiles.first }
    private let questions = LegacyQuestions.questions

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                if showingResult {
                    resultView
                } else {
                    questionView
                }
            }
            .navigationTitle(String(localized: "legacy.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                
                if !showingResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "common.save")) {
                            saveResult()
                        }
                        .disabled(answers.allSatisfy { $0.isEmpty } || isSaving)
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
                    .fill(Color.teal)
                    .frame(width: geometry.size.width * Double(currentQuestionIndex + 1) / Double(questions.count))
                    .animation(.easeInOut, value: currentQuestionIndex)
            }
        }
        .frame(height: 4)
    }

    private var questionView: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(String(localized: "assessment.question \(currentQuestionIndex + 1) \(questions.count)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(questions[currentQuestionIndex])
                        .font(.title3)
                        .fontWeight(.medium)

                    TextEditor(text: $answers[currentQuestionIndex])
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.teal.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding()
            }

            HStack(spacing: 20) {
                if currentQuestionIndex > 0 {
                    Button {
                        withAnimation { currentQuestionIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }

                Spacer()

                if currentQuestionIndex < questions.count - 1 {
                    Button {
                        withAnimation { currentQuestionIndex += 1 }
                    } label: {
                        HStack {
                            Text(String(localized: "assessment.next"))
                            Image(systemName: "chevron.right")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                } else {
                    Button {
                        saveResult()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(String(localized: "assessment.complete"))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .disabled(isSaving)
                }
            }
            .padding()
        }
    }

    private var resultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.teal)
                    Text(String(localized: "assessment.complete.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)

                // AI Analysis Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(String(localized: "assessment.ai_analysis"))
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.teal)

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
                        Text("Analysis will appear here...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.teal.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                )

                Text(String(localized: "legacy.result.desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                ForEach(0..<questions.count, id: \.self) { index in
                    if !answers[index].isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(questions[index])
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.teal)
                            
                            Text(answers[index])
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "common.done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top)
            }
            .padding()
        }
    }

    private func saveResult() {
        isSaving = true
        isAnalyzing = true
        
        let assessment = AssessmentResult(type: .legacy)
        assessment.setAnswers(answers)
        assessment.complete(resultCode: "completed")
        
        modelContext.insert(assessment)
        
        if let profile = profile {
            profile.assessmentCount += 1
            profile.updateCompleteness()
        }
        
        try? modelContext.save()
        result = assessment
        showingResult = true
        isSaving = false

        Task {
            if let profile = profile {
                await SoulService.shared.processLegacyResult(
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

#Preview {
    LegacyAssessmentView()
        .modelContainer(for: [AssessmentResult.self, SoulProfile.self], inMemory: true)
}
