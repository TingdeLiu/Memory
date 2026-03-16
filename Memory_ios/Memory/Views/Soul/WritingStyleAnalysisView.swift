import SwiftUI
import SwiftData

struct WritingStyleAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memories: [MemoryEntry]

    @Bindable var profile: WritingStyleProfile

    private var writingService: WritingStyleService { WritingStyleService.shared }
    @State private var aiService = AIService()
    @State private var isAnalyzing = false
    @State private var analysisComplete = false
    @State private var analysisError: String?

    private var textMemories: [MemoryEntry] {
        memories.filter { !$0.content.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if analysisComplete {
                    completionView
                } else if isAnalyzing {
                    analyzingView
                } else {
                    setupView
                }
            }
            .padding()
            .navigationTitle(String(localized: "writing.analysis.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isAnalyzing {
                        Button(String(localized: "common.cancel")) {
                            dismiss()
                        }
                    }
                }
            }
            .alert(String(localized: "writing.error.title"), isPresented: .init(
                get: { analysisError != nil },
                set: { if !$0 { analysisError = nil } }
            )) {
                Button(String(localized: "common.done")) {
                    analysisError = nil
                }
            } message: {
                if let error = analysisError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "wand.and.rays")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }

            // Info
            VStack(spacing: 8) {
                Text(String(localized: "writing.analysis.ready"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "writing.analysis.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Data Summary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text(String(localized: "writing.analysis.memories \(textMemories.count)"))
                }

                HStack {
                    Image(systemName: "character.cursor.ibeam")
                        .foregroundStyle(.green)
                    Text(String(localized: "writing.analysis.words \(estimatedWordCount)"))
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.orange)
                    Text(String(localized: "writing.analysis.time"))
                }
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // API Check
            if !aiService.isConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(String(localized: "writing.analysis.need_ai"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // Privacy Note
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                Text(String(localized: "writing.analysis.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Start Button
            Button {
                startAnalysis()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(String(localized: "writing.analysis.start"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canAnalyze)
        }
    }

    private var estimatedWordCount: Int {
        textMemories.reduce(0) { $0 + $1.content.count / 2 }  // Rough estimate
    }

    private var canAnalyze: Bool {
        textMemories.count >= WritingStyleConstants.minimumMemories && aiService.isConfigured
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "gearshape.2")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(writingService.analysisProgress * 360))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: writingService.analysisProgress)
            }

            // Status
            VStack(spacing: 8) {
                Text(String(localized: "writing.analysis.in_progress"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(analysisStageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: writingService.analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(.orange)

                Text(String(localized: "writing.analysis.progress \(Int(writingService.analysisProgress * 100))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Warning
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)

                Text(String(localized: "writing.analysis.please_wait"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var analysisStageText: String {
        let progress = writingService.analysisProgress
        if progress < 0.2 {
            return String(localized: "writing.stage.extracting")
        } else if progress < 0.4 {
            return String(localized: "writing.stage.words")
        } else if progress < 0.6 {
            return String(localized: "writing.stage.patterns")
        } else if progress < 0.8 {
            return String(localized: "writing.stage.ai")
        } else {
            return String(localized: "writing.stage.finishing")
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }

            // Success Message
            VStack(spacing: 8) {
                Text(String(localized: "writing.analysis.complete"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "writing.analysis.complete_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Stats
            HStack(spacing: 24) {
                StatBadge(
                    value: "\(profile.memoriesAnalyzed)",
                    label: String(localized: "writing.stat.memories"),
                    color: .blue
                )

                StatBadge(
                    value: "\(profile.totalWordsAnalyzed)",
                    label: String(localized: "writing.stat.words"),
                    color: .green
                )
            }

            // Preview of style
            if let style = profile.styleDescription, !style.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "writing.your_style"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(style)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Done Button
            Button {
                dismiss()
            } label: {
                Text(String(localized: "common.done"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private func startAnalysis() {
        isAnalyzing = true

        Task {
            do {
                try await writingService.analyzeStyle(
                    profile: profile,
                    memories: textMemories,
                    aiService: aiService
                )
                try? modelContext.save()
                analysisComplete = true
            } catch {
                analysisError = error.localizedDescription
                profile.failAnalysis()
            }
            isAnalyzing = false
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WritingStyleAnalysisView(profile: WritingStyleProfile())
        .modelContainer(for: [WritingStyleProfile.self, MemoryEntry.self], inMemory: true)
}
