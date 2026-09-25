//
//  PremiumStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation
import StoreKit

enum PremiumProductID {
    static let weekly = "zimma.MazeArrows.premium.weekly"
    static let annual = "zimma.MazeArrows.premium.annual"
    static let all = [weekly, annual]
}

@MainActor
@Observable
final class PremiumStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case pending
        case cancelled
        case purchased
        case failed(String)
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var loadState: LoadState = .idle
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var hasLoadedEntitlements = false

    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var productLoadingTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
        productLoadingTask?.cancel()
    }

    var weeklyProduct: Product? {
        products.first { $0.id == PremiumProductID.weekly }
    }

    var annualProduct: Product? {
        products.first { $0.id == PremiumProductID.annual }
    }

    var hasAvailablePaywall: Bool {
        weeklyProduct != nil && annualProduct != nil
    }

    var isPremium: Bool {
        !purchasedProductIDs.isDisjoint(with: PremiumProductID.all)
    }

    func start() async {
        startTransactionListenerIfNeeded()
        await processUnfinishedTransactions()
        await refreshEntitlements()
        await loadProductsIfNeeded()
    }

    func loadProductsIfNeeded(
        force: Bool = false,
        waitTimeout: Duration? = nil
    ) async {
        guard force || products.isEmpty else { return }
        if let productLoadingTask {
            await waitForProductLoad(productLoadingTask, timeout: waitTimeout)
            return
        }

        loadState = .loading
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performProductLoad()
        }
        productLoadingTask = task
        await waitForProductLoad(task, timeout: waitTimeout)
    }

    private func performProductLoad() async {
        defer { productLoadingTask = nil }

        do {
            let loaded = try await Product.products(for: PremiumProductID.all)
            products = loaded.sorted { lhs, rhs in
                if lhs.id == PremiumProductID.weekly { return true }
                if rhs.id == PremiumProductID.weekly { return false }
                return lhs.price < rhs.price
            }
            loadState = hasAvailablePaywall ? .loaded : .unavailable
        } catch {
            products = []
            loadState = .unavailable
        }
    }

    private func waitForProductLoad(
        _ task: Task<Void, Never>,
        timeout: Duration?
    ) async {
        guard let timeout else {
            await task.value
            return
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while loadState == .loading, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                guard transaction.revocationDate == nil else {
                    purchaseState = .failed(OnboardingCopy.purchaseFailed)
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .purchased
                return true

            case .userCancelled:
                purchaseState = .cancelled
                return false

            case .pending:
                purchaseState = .pending
                return false

            @unknown default:
                purchaseState = .failed(OnboardingCopy.purchaseFailed)
                return false
            }
        } catch {
            purchaseState = .failed(OnboardingCopy.purchaseFailed)
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        purchaseState = .purchasing
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isPremium ? .purchased : .idle
            return isPremium
        } catch {
            purchaseState = .failed(OnboardingCopy.restoreFailed)
            return false
        }
    }

    func resetPurchaseMessage() {
        if purchaseState != .purchasing {
            purchaseState = .idle
        }
    }

    func refreshEntitlements() async {
        var current = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  PremiumProductID.all.contains(transaction.productID)
            else { continue }
            current.insert(transaction.productID)
        }
        purchasedProductIDs = current
        hasLoadedEntitlements = true
    }

    private func startTransactionListenerIfNeeded() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      PremiumProductID.all.contains(transaction.productID)
                else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  PremiumProductID.all.contains(transaction.productID)
            else { continue }
            await transaction.finish()
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
