import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage(
                icon: "brain.head.profile",
                iconColor: .accent,
                title: String(localized: "onboarding.welcome.title"),
                subtitle: String(localized: "onboarding.welcome.subtitle"),
                buttonTitle: nil,
                action: nil
            )
            .tag(0)

            OnboardingPage(
                icon: "lock.shield.fill",
                iconColor: .green,
                title: String(localized: "onboarding.privacy.title"),
                subtitle: String(localized: "onboarding.privacy.subtitle"),
                buttonTitle: nil,
                action: nil
            )
            .tag(1)

            OnboardingPage(
                icon: "heart.fill",
                iconColor: .pink,
                title: String(localized: "onboarding.start.title"),
                subtitle: String(localized: "onboarding.start.subtitle"),
                buttonTitle: String(localized: "onboarding.getStarted"),
                action: { hasCompletedOnboarding = true }
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(iconColor)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
