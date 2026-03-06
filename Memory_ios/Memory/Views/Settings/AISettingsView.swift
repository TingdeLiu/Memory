import SwiftUI

struct AISettingsView: View {
    @State private var aiService = AIService()
    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("aiProvider") private var providerRaw = AIProvider.claude.rawValue
    @AppStorage("aiAllowPrivateMemories") private var allowPrivateMemories = false

    @State private var apiKeyInput = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showingClearConfirmation = false

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .claude
    }

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            // Enable/Disable
            Section {
                Toggle(isOn: $aiEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "aiSettings.enableAI"))
                            Text(String(localized: "aiSettings.enableSubtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            }

            if aiEnabled {
                // Provider Selection
                providerSection

                // API Key
                apiKeySection

                // Custom Endpoint
                if selectedProvider == .custom {
                    customEndpointSection
                }

                // Model Selection
                if selectedProvider != .custom {
                    modelSection
                }

                // Privacy
                privacySection

                // Connection Test
                connectionSection
            }
        }
        .navigationTitle(String(localized: "aiSettings.title"))
        .onAppear {
            apiKeyInput = ""
            testResult = nil
        }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        Section(String(localized: "aiSettings.provider")) {
            Picker(String(localized: "aiSettings.providerLabel"), selection: $providerRaw) {
                ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                    Text(provider.name).tag(provider.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        Section {
            HStack {
                Text(String(localized: "aiSettings.status"))
                Spacer()
                if aiService.hasAPIKey(for: selectedProvider) {
                    Label(String(localized: "aiSettings.configured"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Label(String(localized: "aiSettings.notSet"), systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            SecureField(String(localized: "aiSettings.enterKey"), text: $apiKeyInput)
                .textContentType(.password)
                .autocorrectionDisabled()

            Button(String(localized: "aiSettings.saveKey")) {
                aiService.saveAPIKey(apiKeyInput, for: selectedProvider)
                apiKeyInput = ""
            }
            .disabled(apiKeyInput.isEmpty)

            if aiService.hasAPIKey(for: selectedProvider) {
                Button(String(localized: "aiSettings.clearKey"), role: .destructive) {
                    showingClearConfirmation = true
                }
                .confirmationDialog(
                    String(localized: "aiSettings.clearKeyConfirm"),
                    isPresented: $showingClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "aiSettings.clearButton"), role: .destructive) {
                        aiService.deleteAPIKey(for: selectedProvider)
                    }
                } message: {
                    Text(L10n.clearKeyMessage(selectedProvider.name))
                }
            }
        } header: {
            Text(String(localized: "aiSettings.apiKey"))
        } footer: {
            Text(String(localized: "aiSettings.apiKeyFooter"))
        }
    }

    // MARK: - Custom Endpoint Section

    private var customEndpointSection: some View {
        Section {
            TextField(String(localized: "aiSettings.baseURL"), text: Binding(
                get: { aiService.customBaseURL },
                set: { aiService.customBaseURL = $0 }
            ))
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            TextField(String(localized: "aiSettings.modelName"), text: Binding(
                get: { aiService.customModelName },
                set: { aiService.customModelName = $0 }
            ))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        } header: {
            Text(String(localized: "aiSettings.customEndpoint"))
        } footer: {
            Text(String(localized: "aiSettings.customFooter"))
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section(String(localized: "aiSettings.model")) {
            Picker(String(localized: "aiSettings.model"), selection: Binding(
                get: { aiService.selectedModel },
                set: { aiService.selectedModel = $0 }
            )) {
                ForEach(selectedProvider.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            Toggle(isOn: $allowPrivateMemories) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "aiSettings.includePrivate"))
                        Text(String(localized: "aiSettings.includePrivateSubtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.open")
                }
            }
        } header: {
            Text(String(localized: "aiSettings.privacy"))
        } footer: {
            Text(String(localized: "aiSettings.privacyFooter"))
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            Button {
                testConnection()
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Text(isTesting ? String(localized: "aiSettings.testing") : String(localized: "aiSettings.testConnection"))
                }
            }
            .disabled(isTesting || !aiService.hasAPIKey(for: selectedProvider))

            if let testResult {
                switch testResult {
                case .success:
                    Label(String(localized: "aiSettings.connectionSuccess"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                case .failure(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                _ = try await aiService.testConnection()
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
