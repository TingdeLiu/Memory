import SwiftUI
import StoreKit

struct PurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    private var store: StoreService { StoreService.shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Feature comparison
                    featureComparison

                    // Price & Purchase
                    purchaseSection

                    // Restore
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text(String(localized: "purchase.restore"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Legal
                    legalLinks

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(String(localized: "purchase.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "purchase.close")) { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text(String(localized: "purchase.title"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "purchase.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text(String(localized: "purchase.feature"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(localized: "purchase.free"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60)
                Text(String(localized: "purchase.premium"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 70)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            featureRow(String(localized: "purchase.textMemories"), free: String(localized: "purchase.unlimited"), premium: String(localized: "purchase.unlimited"))
            featureRow(String(localized: "purchase.voiceMemories"), free: "3", premium: String(localized: "purchase.unlimited"))
            featureRow(String(localized: "purchase.contacts"), free: "5", premium: String(localized: "purchase.unlimited"))
            featureRow(String(localized: "purchase.aiFeatures"), free: false, premium: true)
            featureRow(String(localized: "purchase.encryptedExport"), free: false, premium: true)
            featureRow(String(localized: "purchase.iCloudSync"), free: true, premium: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    private func featureRow(_ feature: String, free: String, premium: String) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60)
            Text(premium)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
                .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func featureRow(_ feature: String, free: Bool, premium: Bool) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(free ? .green : .secondary)
                .frame(width: 60)
            Image(systemName: premium ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(premium ? Color.accentColor : .secondary)
                .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView()
                    .padding()
            } else if let product = store.products.first {
                if store.isPremium {
                    Label(String(localized: "purchase.youHavePremium"), systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding()
                } else {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        VStack(spacing: 4) {
                            Text(L10n.purchaseFor(product.displayPrice))
                                .font(.headline)
                            Text(String(localized: "purchase.oneTime"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(String(localized: "purchase.productUnavailable"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = store.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link(String(localized: "purchase.termsOfUse"), destination: URL(string: "https://memory.app/terms")!)
            Text("·").foregroundStyle(.tertiary)
            Link(String(localized: "purchase.privacyPolicy"), destination: URL(string: "https://memory.app/privacy")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    PurchaseView()
}
