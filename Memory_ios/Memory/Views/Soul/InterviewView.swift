import SwiftUI
import SwiftData

struct InterviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let interviewType: InterviewType
    var topic: InterviewTopic?
    var contact: Contact?

    @State private var interviewService = InterviewService()
    @State private var aiService = AIService()
    @State private var currentAnswer = ""
    @State private var isCompleting = false
    @State private var showingTopicPicker = false

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                progressBar

                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Interview Header
                            interviewHeader

                            // Conversation
                            conversationView

                            // Scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: interviewService.currentSession?.questions.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                // Input Area
                if interviewService.isActive {
                    inputArea
                }
            }
            .navigationTitle(interviewType.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "interview.skip")) {
                        interviewService.skipInterview()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if interviewService.isActive {
                        Button(String(localized: "interview.finish")) {
                            Task {
                                isCompleting = true
                                await interviewService.completeInterview()
                                isCompleting = false
                                dismiss()
                            }
                        }
                        .disabled(interviewService.answeredCount < 2)
                    }
                }
            }
            .sheet(isPresented: $showingTopicPicker) {
                topicPickerSheet
            }
            .onAppear {
                startInterview()
            }
            .overlay {
                if isCompleting {
                    completingOverlay
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
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * interviewService.progress)
                    .animation(.easeInOut, value: interviewService.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Interview Header

    private var interviewHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: interviewType.icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(headerTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Image(systemName: "clock")
                Text(String(localized: "interview.estimated \(interviewType.estimatedMinutes)"))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical)
    }

    private var headerTitle: String {
        switch interviewType {
        case .onboarding:
            return String(localized: "interview.onboarding.title")
        case .periodic:
            return String(localized: "interview.periodic.title")
        case .milestone:
            return String(localized: "interview.milestone.title")
        case .deepDive:
            if let topic = topic {
                return topic.label
            }
            return String(localized: "interview.deepdive.title")
        case .relationship:
            if let contact = contact {
                return String(localized: "interview.relationship.title \(contact.name)")
            }
            return String(localized: "interview.relationship.generic")
        }
    }

    private var headerSubtitle: String {
        switch interviewType {
        case .onboarding:
            return String(localized: "interview.onboarding.subtitle")
        case .periodic:
            return String(localized: "interview.periodic.subtitle")
        case .milestone:
            return String(localized: "interview.milestone.subtitle")
        case .deepDive:
            return topic?.description ?? String(localized: "interview.deepdive.subtitle")
        case .relationship:
            return String(localized: "interview.relationship.subtitle")
        }
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        VStack(spacing: 12) {
            if let session = interviewService.currentSession {
                ForEach(Array(zip(session.questions.indices, session.questions)), id: \.0) { index, question in
                    // AI Question
                    InterviewMessageBubble(text: question, isUser: false)

                    // User Answer (if exists)
                    if index < session.answers.count {
                        let answer = session.answers[index]
                        if answer != "[skipped]" {
                            InterviewMessageBubble(text: answer, isUser: true)
                        } else {
                            HStack {
                                Spacer()
                                Text(String(localized: "interview.skipped"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                    }
                }

                // Typing indicator when waiting for AI
                if interviewService.isWaitingForAI {
                    HStack {
                        TypingIndicator()
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 12) {
                // Skip question button
                Button {
                    Task {
                        _ = await interviewService.skipQuestion()
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .foregroundStyle(.secondary)
                }
                .disabled(interviewService.isWaitingForAI)

                // Text input
                TextField(String(localized: "interview.placeholder"), text: $currentAnswer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .disabled(interviewService.isWaitingForAI)

                // Send button
                Button {
                    submitAnswer()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(currentAnswer.isEmpty ? .secondary : .blue)
                }
                .disabled(currentAnswer.isEmpty || interviewService.isWaitingForAI)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Topic Picker

    private var topicPickerSheet: some View {
        NavigationStack {
            List(InterviewTopic.allCases, id: \.self) { topic in
                Button {
                    showingTopicPicker = false
                    startDeepDiveInterview(topic: topic)
                } label: {
                    HStack {
                        Image(systemName: topic.icon)
                            .foregroundStyle(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading) {
                            Text(topic.label)
                                .foregroundStyle(.primary)
                            Text(topic.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "interview.choose_topic"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.cancel")) {
                        showingTopicPicker = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Completing Overlay

    private var completingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(String(localized: "interview.completing"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func startInterview() {
        if interviewType == .deepDive && topic == nil {
            showingTopicPicker = true
            return
        }

        if let contact = contact {
            _ = interviewService.startRelationshipInterview(
                contact: contact,
                aiService: aiService,
                context: modelContext
            )
        } else {
            _ = interviewService.startInterview(
                type: interviewType,
                topic: topic,
                aiService: aiService,
                context: modelContext
            )
        }

        isInputFocused = true
    }

    private func startDeepDiveInterview(topic: InterviewTopic) {
        _ = interviewService.startInterview(
            type: .deepDive,
            topic: topic,
            aiService: aiService,
            context: modelContext
        )
        isInputFocused = true
    }

    private func submitAnswer() {
        let answer = currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }

        currentAnswer = ""

        Task {
            _ = await interviewService.submitAnswer(answer)

            // Check if interview is complete
            if interviewService.currentQuestion == nil && !interviewService.isWaitingForAI {
                isCompleting = true
                await interviewService.completeInterview()
                isCompleting = false
                dismiss()
            }
        }
    }
}

// MARK: - Message Bubble

private struct InterviewMessageBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isUser ? Color.blue : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: false)) {
                animationPhase = 3
            }
        }
    }
}

#Preview {
    InterviewView(interviewType: .onboarding)
        .modelContainer(for: [SoulProfile.self, InterviewSession.self], inMemory: true)
}
