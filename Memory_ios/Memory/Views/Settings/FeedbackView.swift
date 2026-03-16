import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var feedbackType: FeedbackType = .suggestion
    @State private var feedbackContent = ""
    @State private var contactEmail = ""
    @State private var includeDeviceInfo = true
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingMailComposer = false

    private let feedbackService = FeedbackService.shared

    var body: some View {
        NavigationStack {
            Form {
                // Feedback Type
                Section {
                    Picker(String(localized: "feedback.type"), selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } header: {
                    Text(String(localized: "feedback.type.header"))
                } footer: {
                    Text(feedbackType.description)
                }

                // Feedback Content
                Section {
                    TextEditor(text: $feedbackContent)
                        .frame(minHeight: 150)
                        .overlay(alignment: .topLeading) {
                            if feedbackContent.isEmpty {
                                Text(String(localized: "feedback.content.placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text(String(localized: "feedback.content.header"))
                } footer: {
                    Text(String(localized: "feedback.content.footer"))
                }

                // Contact Email (Optional)
                Section {
                    TextField(String(localized: "feedback.email.placeholder"), text: $contactEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Text(String(localized: "feedback.email.header"))
                } footer: {
                    Text(String(localized: "feedback.email.footer"))
                }

                // Device Info
                Section {
                    Toggle(String(localized: "feedback.device_info"), isOn: $includeDeviceInfo)

                    if includeDeviceInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            deviceInfoRow(String(localized: "feedback.device"), feedbackService.deviceModel)
                            deviceInfoRow(String(localized: "feedback.ios_version"), feedbackService.iOSVersion)
                            deviceInfoRow(String(localized: "feedback.app_version"), feedbackService.appVersion)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(String(localized: "feedback.device_info.footer"))
                }

                // Submit
                Section {
                    Button {
                        submitFeedback()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(String(localized: "feedback.submit"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(feedbackContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    // Alternative: Email directly
                    Button {
                        sendViaEmail()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "envelope")
                            Text(String(localized: "feedback.send_email"))
                            Spacer()
                        }
                    }
                    .disabled(feedbackContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(String(localized: "feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "feedback.success.title"), isPresented: $showingSuccess) {
                Button(String(localized: "common.done")) {
                    dismiss()
                }
            } message: {
                Text(String(localized: "feedback.success.message"))
            }
            .alert(String(localized: "feedback.error.title"), isPresented: $showingError) {
                Button(String(localized: "common.ok")) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    subject: feedbackService.emailSubject(for: feedbackType),
                    body: feedbackService.emailBody(
                        content: feedbackContent,
                        type: feedbackType,
                        email: contactEmail,
                        includeDeviceInfo: includeDeviceInfo
                    ),
                    recipients: [feedbackService.feedbackEmail]
                )
            }
        }
    }

    private func deviceInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func submitFeedback() {
        isSubmitting = true

        Task {
            do {
                try await feedbackService.submitFeedback(
                    type: feedbackType,
                    content: feedbackContent,
                    email: contactEmail.isEmpty ? nil : contactEmail,
                    includeDeviceInfo: includeDeviceInfo
                )
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func sendViaEmail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            // Fallback to mailto URL
            let subject = feedbackService.emailSubject(for: feedbackType)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = feedbackService.emailBody(
                content: feedbackContent,
                type: feedbackType,
                email: contactEmail,
                includeDeviceInfo: includeDeviceInfo
            ).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            if let url = URL(string: "mailto:\(feedbackService.feedbackEmail)?subject=\(subject)&body=\(body)") {
                openURL(url)
            }
        }
    }
}

// MARK: - Feedback Type

enum FeedbackType: String, CaseIterable, Codable {
    case bug
    case suggestion
    case feature
    case question
    case praise

    var label: String {
        switch self {
        case .bug: return String(localized: "feedback.type.bug")
        case .suggestion: return String(localized: "feedback.type.suggestion")
        case .feature: return String(localized: "feedback.type.feature")
        case .question: return String(localized: "feedback.type.question")
        case .praise: return String(localized: "feedback.type.praise")
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .suggestion: return "lightbulb"
        case .feature: return "star"
        case .question: return "questionmark.circle"
        case .praise: return "heart"
        }
    }

    var description: String {
        switch self {
        case .bug: return String(localized: "feedback.type.bug.desc")
        case .suggestion: return String(localized: "feedback.type.suggestion.desc")
        case .feature: return String(localized: "feedback.type.feature.desc")
        case .question: return String(localized: "feedback.type.question.desc")
        case .praise: return String(localized: "feedback.type.praise.desc")
        }
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

#Preview {
    FeedbackView()
}
