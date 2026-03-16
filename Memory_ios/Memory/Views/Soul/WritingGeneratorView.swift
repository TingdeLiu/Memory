import SwiftUI
import SwiftData

struct WritingGeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [Contact]

    @Bindable var profile: WritingStyleProfile

    private var writingService: WritingStyleService { WritingStyleService.shared }
    @State private var aiService = AIService()

    @State private var mode: GeneratorMode = .freeform
    @State private var freeformPrompt = ""
    @State private var selectedContact: Contact?
    @State private var selectedOccasion: WritingOccasion = .gratitude
    @State private var customOccasion = ""
    @State private var generatedText = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var showingCopied = false

    enum GeneratorMode: String, CaseIterable {
        case freeform = "freeform"
        case message = "message"

        var label: String {
            switch self {
            case .freeform: return String(localized: "writing.mode.freeform")
            case .message: return String(localized: "writing.mode.message")
            }
        }

        var icon: String {
            switch self {
            case .freeform: return "text.cursor"
            case .message: return "envelope"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Selector
                    modeSelector

                    // Input Section
                    if mode == .freeform {
                        freeformInput
                    } else {
                        messageInput
                    }

                    // Generate Button
                    generateButton

                    // Output Section
                    if !generatedText.isEmpty {
                        outputSection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "writing.generator.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "writing.error.title"), isPresented: .init(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )) {
                Button(String(localized: "common.done")) {
                    generationError = nil
                }
            } message: {
                if let error = generationError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(GeneratorMode.allCases, id: \.rawValue) { generatorMode in
                Button {
                    withAnimation {
                        mode = generatorMode
                        generatedText = ""
                    }
                } label: {
                    HStack {
                        Image(systemName: generatorMode.icon)
                        Text(generatorMode.label)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(mode == generatorMode ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundStyle(mode == generatorMode ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Freeform Input

    private var freeformInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "writing.freeform.title"))
                .font(.headline)

            Text(String(localized: "writing.freeform.desc"))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(String(localized: "writing.freeform.placeholder"), text: $freeformPrompt, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            // Example prompts
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "writing.examples"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(examplePrompts, id: \.self) { example in
                    Button {
                        freeformPrompt = example
                    } label: {
                        Text(example)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var examplePrompts: [String] {
        [
            String(localized: "writing.example.diary"),
            String(localized: "writing.example.reflection"),
            String(localized: "writing.example.memory")
        ]
    }

    // MARK: - Message Input

    private var messageInput: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Contact Selection
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "writing.message.to"))
                    .font(.headline)

                if contacts.isEmpty {
                    Text(String(localized: "writing.message.no_contacts"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(contacts) { contact in
                                ContactChip(
                                    contact: contact,
                                    isSelected: selectedContact?.id == contact.id
                                ) {
                                    selectedContact = contact
                                }
                            }
                        }
                    }
                }
            }

            // Occasion Selection
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "writing.message.occasion"))
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(WritingOccasion.allCases, id: \.rawValue) { occasion in
                        OccasionChip(
                            occasion: occasion,
                            isSelected: selectedOccasion == occasion
                        ) {
                            selectedOccasion = occasion
                        }
                    }
                }
            }

            // Custom Occasion Input
            if selectedOccasion == .custom {
                TextField(String(localized: "writing.message.custom_occasion"), text: $customOccasion)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            generate()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isGenerating
                     ? String(localized: "writing.generating")
                     : String(localized: "writing.generate_button"))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: canGenerate ? [.purple, .blue] : [.gray, .gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canGenerate || isGenerating)
    }

    private var canGenerate: Bool {
        if mode == .freeform {
            return !freeformPrompt.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedContact != nil
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "writing.result"))
                    .font(.headline)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopied ? "checkmark" : "doc.on.doc")
                        Text(showingCopied
                             ? String(localized: "common.copied")
                             : String(localized: "common.copy"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }

                Button {
                    generatedText = ""
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Text(generatedText)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Use in Message Button
            if mode == .message, let contact = selectedContact {
                NavigationLink {
                    MessageEditorView(contact: contact, prefillContent: generatedText)
                } label: {
                    HStack {
                        Image(systemName: "envelope.badge.fill")
                        Text(String(localized: "writing.use_as_message"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            }

            // Regenerate
            Button {
                generate()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(String(localized: "writing.regenerate"))
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func generate() {
        isGenerating = true
        generatedText = ""

        Task {
            do {
                if mode == .freeform {
                    generatedText = try await writingService.generateInStyle(
                        prompt: freeformPrompt,
                        profile: profile,
                        aiService: aiService
                    )
                } else if let contact = selectedContact {
                    generatedText = try await writingService.generateDraft(
                        for: contact,
                        occasion: selectedOccasion,
                        customPrompt: selectedOccasion == .custom ? customOccasion : nil,
                        profile: profile,
                        aiService: aiService
                    )
                }
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = generatedText
        showingCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopied = false
        }
    }
}

// MARK: - Contact Chip

private struct ContactChip: View {
    let contact: Contact
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(contact.relationship.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    if let photoData = contact.avatarData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        Text(contact.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(contact.relationship.color)
                    }

                    if isSelected {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                }

                Text(contact.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .blue : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Occasion Chip

private struct OccasionChip: View {
    let occasion: WritingOccasion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: occasion.icon)
                    .font(.caption)
                Text(occasion.label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WritingGeneratorView(profile: WritingStyleProfile())
        .modelContainer(for: [WritingStyleProfile.self, Contact.self], inMemory: true)
}
