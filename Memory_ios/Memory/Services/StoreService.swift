import Foundation
import StoreKit
import SwiftUI

@Observable
final class StoreService {
    static let shared = StoreService()
    static let premiumProductID = "com.tyndall.memory.premium"

    var products: [Product] = []
    var isPremium: Bool = false
    var purchaseError: String?
    var isLoading: Bool = false

    @ObservationIgnored
    @AppStorage("isPremiumCached") private var isPremiumCached = false

    @ObservationIgnored
    private var transactionListener: Task<Void, Never>?

    // MARK: - Feature Gating

    var canCreateVoiceMemory: Bool { true }  // Free
    var canCreateVideoMemory: Bool { true }  // Free
    var canUseAI: Bool { isPremium }
    var canExportEncrypted: Bool { isPremium }
    var canUseDigitalSelf: Bool { isPremium }
    var contactLimit: Int { Int.max }  // Free unlimited
    var voiceMemoryLimit: Int { Int.max }  // Free unlimited
    var videoMemoryLimit: Int { Int.max }  // Free unlimited

    // MARK: - Init

    private init() {
        isPremium = isPremiumCached
        transactionListener = listenForTransactions()
        Task { await checkEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            products = try await Product.products(for: [Self.premiumProductID])
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = products.first else {
            purchaseError = "Product not available."
            return
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePremiumStatus(true)
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Entitlements

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.premiumProductID {
                await updatePremiumStatus(true)
                return
            }
        }
        await updatePremiumStatus(false)
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    if transaction.productID == Self.premiumProductID {
                        await self?.updatePremiumStatus(true)
                    }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    @MainActor
    private func updatePremiumStatus(_ premium: Bool) {
        isPremium = premium
        isPremiumCached = premium
    }
}
