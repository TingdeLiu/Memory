import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var authError: String?
    @State private var isAuthenticating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var biometricType: BiometricAuth.BiometricType {
        BiometricAuth.availableType
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(.accent)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    Text("Memory")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(logoOpacity)

                    Text(String(localized: "lockScreen.protected"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(logoOpacity)
                }

                Spacer()

                // Auth section
                VStack(spacing: 16) {
                    if let error = authError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Button {
                        authenticate()
                    } label: {
                        HStack(spacing: 8) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: biometricType.systemImage)
                            }
                            Text(L10n.lockScreenUnlock(biometricType.displayName))
                        }
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAuthenticating)
                    .accessibilityLabel(L10n.lockScreenUnlock(biometricType.displayName))
                    .accessibilityHint(String(localized: "lockScreen.unlockHint"))
                    .sensoryFeedback(.success, trigger: isUnlocked)
                    .sensoryFeedback(.error, trigger: authError)

                    if biometricType != .none {
                        Button {
                            authenticateWithPasscode()
                        } label: {
                            Text(String(localized: "lockScreen.usePasscode"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
            .padding()
        }
        .onAppear {
            if reduceMotion {
                logoScale = 1.0
                logoOpacity = 1.0
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.1 : 0.3)) {
                authenticate()
            }
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil

        Task {
            let success = await BiometricAuth.authenticate()
            await MainActor.run {
                isAuthenticating = false
                if success {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isUnlocked = true
                    }
                } else {
                    authError = String(localized: "lockScreen.authFailed")
                }
            }
        }
    }

    private func authenticateWithPasscode() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "lockScreen.unlockHint")
        ) { success, error in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isUnlocked = true
                    }
                } else {
                    authError = error?.localizedDescription ?? "Passcode authentication failed."
                }
            }
        }
    }
}

#Preview {
    LockScreenView(isUnlocked: .constant(false))
}
