import SwiftUI
import SwiftData

struct WritingStyleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [WritingStyleProfile]
    @Query private var memories: [MemoryEntry]

    private var writingService: WritingStyleService { WritingStyleService.shared }
    @State private var aiService = AIService()
    @State private var showingAnalysis = false
    @State private var showingGenerator = false
    @State private var showingSettings = false
    @State private var analysisError: String?

    private var profile: WritingStyleProfile? {
        profiles.first
    }

    private var textMemories: [MemoryEntry] {
        memories.filter { !$0.content.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    statusCard

                    // Progress Section (when not ready)
                    if profile?.status != .ready {
                        progressSection
                    }

                    // Style Summary (when ready)
                    if profile?.isReady == true {
                        styleSummarySection
                    }

                    // Actions
                    actionsSection

                    // Word Cloud (when ready)
                    if profile?.isReady == true {
                        wordCloudSection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "writing.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAnalysis) {
                WritingStyleAnalysisView(profile: ensureProfile())
            }
            .sheet(isPresented: $showingGenerator) {
                WritingGeneratorView(profile: ensureProfile())
            }
            .sheet(isPresented: $showingSettings) {
                WritingStyleSettingsView(profile: ensureProfile())
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
            .onAppear {
                ensureProfileExists()
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: profile?.status.icon ?? "pencil.and.outline")
                    .font(.system(size: 32))
                    .foregroundStyle(statusColor)
            }

            // Status Text
            VStack(spacing: 4) {
                Text(profile?.statusDescription ?? String(localized: "writing.status.not_analyzed"))
                    .font(.title3)
                    .fontWeight(.semibold)

                statusSubtitle
            }

            // Generate Button (when ready)
            if profile?.isReady == true {
                Button {
                    showingGenerator = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(String(localized: "writing.generate"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        switch profile?.status {
        case .notAnalyzed, .none:
            Text(String(localized: "writing.status.not_analyzed.desc"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

        case .analyzing:
            VStack(spacing: 8) {
                Text(String(localized: "writing.status.analyzing.desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView(value: writingService.analysisProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            }

        case .ready:
            if let date = profile?.lastAnalyzedAt {
                Text(String(localized: "writing.last_analyzed \(date.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .failed:
            Text(String(localized: "writing.status.failed.desc"))
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private var statusColor: Color {
        switch profile?.status {
        case .notAnalyzed, .none: return .secondary
        case .analyzing: return .orange
        case .ready: return .green
        case .failed: return .red
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "writing.data_status"))
                    .font(.headline)

                Spacer()

                if textMemories.count >= WritingStyleConstants.minimumMemories {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Memory count
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text(String(localized: "writing.memories_count \(textMemories.count)"))
                    .font(.subheadline)

                Spacer()

                Text(String(localized: "writing.min_required \(WritingStyleConstants.minimumMemories)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            let progress = min(Double(textMemories.count) / Double(WritingStyleConstants.recommendedMemories), 1.0)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)

            // Recommendation
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.orange)

                Text(String(localized: "writing.recommendation"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressBarColor: Color {
        let count = textMemories.count
        if count < WritingStyleConstants.minimumMemories {
            return .red
        } else if count < WritingStyleConstants.recommendedMemories {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Style Summary Section

    private var styleSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "writing.style_summary"))
                .font(.headline)

            if let style = profile?.styleDescription, !style.isEmpty {
                StyleCard(title: String(localized: "writing.overall_style"), content: style, icon: "pencil.line")
            }

            if let tone = profile?.toneDescription, !tone.isEmpty {
                StyleCard(title: String(localized: "writing.tone"), content: tone, icon: "speaker.wave.2")
            }

            if let vocab = profile?.vocabularyLevel, !vocab.isEmpty {
                StyleCard(title: String(localized: "writing.vocabulary"), content: vocab, icon: "textformat.abc")
            }

            if let emotional = profile?.emotionalExpression, !emotional.isEmpty {
                StyleCard(title: String(localized: "writing.emotional"), content: emotional, icon: "heart")
            }

            if let unique = profile?.uniqueTraits, !unique.isEmpty {
                StyleCard(title: String(localized: "writing.unique_traits"), content: unique, icon: "star")
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Analyze Button
            Button {
                if canAnalyze {
                    showingAnalysis = true
                }
            } label: {
                HStack {
                    Image(systemName: "wand.and.rays")
                    Text(profile?.isReady == true
                         ? String(localized: "writing.reanalyze")
                         : String(localized: "writing.start_analysis"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canAnalyze ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canAnalyze || writingService.isAnalyzing)

            if !canAnalyze {
                Text(String(localized: "writing.need_more_memories \(WritingStyleConstants.minimumMemories)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canAnalyze: Bool {
        textMemories.count >= WritingStyleConstants.minimumMemories && !writingService.isAnalyzing
    }

    // MARK: - Word Cloud Section

    private var wordCloudSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "writing.top_words"))
                .font(.headline)

            WritingFlowLayout(spacing: 8) {
                ForEach(Array((profile?.sortedTopWords ?? []).prefix(20).enumerated()), id: \.offset) { index, item in
                    Text(item.word)
                        .font(.system(size: fontSize(for: item.count, index: index)))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(opacity(for: index)))
                        .foregroundStyle(index < 5 ? .white : .primary)
                        .clipShape(Capsule())
                }
            }

            if let phrases = profile?.sortedTopPhrases, !phrases.isEmpty {
                Divider()

                Text(String(localized: "writing.top_phrases"))
                    .font(.headline)

                WritingFlowLayout(spacing: 8) {
                    ForEach(Array(phrases.prefix(10).enumerated()), id: \.offset) { index, item in
                        Text(item.phrase)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fontSize(for count: Int, index: Int) -> CGFloat {
        let baseSize: CGFloat = 14
        let maxSize: CGFloat = 24
        let scale = max(0.5, 1.0 - Double(index) * 0.05)
        return min(maxSize, baseSize + CGFloat(scale) * 8)
    }

    private func opacity(for index: Int) -> Double {
        max(0.2, 0.8 - Double(index) * 0.03)
    }

    // MARK: - Helpers

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let newProfile = WritingStyleProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
        }
    }

    private func ensureProfile() -> WritingStyleProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = WritingStyleProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }
}

// MARK: - Style Card

private struct StyleCard: View {
    let title: String
    let content: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout

private struct WritingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    WritingStyleView()
        .modelContainer(for: [WritingStyleProfile.self, MemoryEntry.self], inMemory: true)
}
