import SwiftUI
import SwiftData

struct AIInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var allMemories: [MemoryEntry]
    @State private var aiService = AIService()
    @State private var summaryResult: String?
    @State private var emotionResult: String?
    @State private var reportResult: String?
    @State private var activeTask: InsightType?
    @State private var showingChat = false

    private var contextMemories: [MemoryEntry] {
        Array(allMemories.filter { !$0.isPrivate }.prefix(50))
    }

    enum InsightType {
        case summary, emotions, report
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    insightCard(
                        title: String(localized: "aiInsights.summary.title"),
                        subtitle: String(localized: "aiInsights.summary.subtitle"),
                        icon: "text.alignleft",
                        color: .accentColor,
                        result: summaryResult,
                        type: .summary
                    )

                    insightCard(
                        title: String(localized: "aiInsights.emotions.title"),
                        subtitle: String(localized: "aiInsights.emotions.subtitle"),
                        icon: "heart.text.square",
                        color: .pink,
                        result: emotionResult,
                        type: .emotions
                    )

                    insightCard(
                        title: String(localized: "aiInsights.report.title"),
                        subtitle: String(localized: "aiInsights.report.subtitle"),
                        icon: "doc.richtext",
                        color: .orange,
                        result: reportResult,
                        type: .report
                    )

                    Button {
                        showingChat = true
                    } label: {
                        Label(String(localized: "aiInsights.chatWithAI"), systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(String(localized: "aiInsights.title"))
            .sheet(isPresented: $showingChat) {
                AIChatView()
            }
        }
    }

    // MARK: - Insight Card

    private func insightCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        result: String?,
        type: InsightType
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if activeTask == type && aiService.isProcessing {
                HStack {
                    ProgressView()
                    Text(String(localized: "aiInsights.generating"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let result {
                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                Button(String(localized: "aiInsights.regenerate")) {
                    generate(type: type)
                }
                .font(.caption)
                .foregroundStyle(color)
            } else {
                Button {
                    generate(type: type)
                } label: {
                    Label(String(localized: "aiInsights.generate"), systemImage: "sparkles")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(color)
            }
        }
        .padding()
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func generate(type: InsightType) {
        activeTask = type
        Task {
            do {
                switch type {
                case .summary:
                    summaryResult = try await aiService.summarizeMemories(contextMemories)
                case .emotions:
                    emotionResult = try await aiService.analyzeEmotionTrends(contextMemories)
                case .report:
                    reportResult = try await aiService.generateAnnualReport(contextMemories)
                }
            } catch {
                switch type {
                case .summary: summaryResult = "Error: \(error.localizedDescription)"
                case .emotions: emotionResult = "Error: \(error.localizedDescription)"
                case .report: reportResult = "Error: \(error.localizedDescription)"
                }
            }
            activeTask = nil
        }
    }
}

#Preview {
    AIInsightsView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}
