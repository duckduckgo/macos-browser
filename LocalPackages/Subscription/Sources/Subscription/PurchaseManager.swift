//
//  PurchaseManager.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import StoreKit
import Common

@available(macOS 12.0, iOS 15.0, *) typealias Transaction = StoreKit.Transaction
@available(macOS 12.0, iOS 15.0, *) typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
@available(macOS 12.0, iOS 15.0, *) typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

enum PurchaseManagerError: Error {
    case productNotFound
    case externalIDisNotAValidUUID
    case purchaseFailed
    case transactionCannotBeVerified
    case transactionPendingAuthentication
    case purchaseCancelledByUser
    case unknownError
}

@available(macOS 12.0, iOS 15.0, *)
public final class PurchaseManager: ObservableObject {

    static let productIdentifiers = ["ios.subscription.1month", "ios.subscription.1year",
                                     "subscription.1week", "subscription.1month", "subscription.1year",
                                     "review.subscription.1week", "review.subscription.1month", "review.subscription.1year"]

    public static let shared = PurchaseManager()

    @Published public private(set) var availableProducts: [Product] = []
    @Published public private(set) var purchasedProductIDs: [String] = []
    @Published public private(set) var purchaseQueue: [String] = []

    @Published private(set) var subscriptionGroupStatus: RenewalState?

    private var transactionUpdates: Task<Void, Never>?
    private var storefrontChanges: Task<Void, Never>?

    public init() {
        transactionUpdates = observeTransactionUpdates()
        storefrontChanges = observeStorefrontChanges()
    }

    deinit {
        transactionUpdates?.cancel()
        storefrontChanges?.cancel()
    }

    @MainActor
    @discardableResult
    public func syncAppleIDAccount() async -> Result<Void, Error> {
        do {
            purchaseQueue.removeAll()

            os_log(.info, log: .subscription, "[PurchaseManager] Before AppStore.sync()")

            try await AppStore.sync()

            os_log(.info, log: .subscription, "[PurchaseManager] After AppStore.sync()")

            await updatePurchasedProducts()
            await updateAvailableProducts()

            return .success(())
        } catch {
            os_log(.error, log: .subscription, "[PurchaseManager] Error: %{public}s", String(reflecting: error))
            return .failure(error)
        }
    }

    @MainActor
    public func updateAvailableProducts() async {
        os_log(.info, log: .subscription, "[PurchaseManager] updateAvailableProducts")

        do {
            let availableProducts = try await Product.products(for: Self.productIdentifiers)
            os_log(.info, log: .subscription, "[PurchaseManager] updateAvailableProducts fetched %d products", availableProducts.count)

            if self.availableProducts != availableProducts {
                self.availableProducts = availableProducts
            }
        } catch {
            os_log(.error, log: .subscription, "[PurchaseManager] Error: %{public}s", String(reflecting: error))
        }
    }

    @MainActor
    public func updatePurchasedProducts() async {
        os_log(.info, log: .subscription, "[PurchaseManager] updatePurchasedProducts")

        var purchasedSubscriptions: [String] = []

        do {
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)

                guard transaction.productType == .autoRenewable else { continue }
                guard transaction.revocationDate == nil else { continue }

                if let expirationDate = transaction.expirationDate, expirationDate > .now {
                    purchasedSubscriptions.append(transaction.productID)
                }
            }
        } catch {
            os_log(.error, log: .subscription, "[PurchaseManager] Error: %{public}s", String(reflecting: error))
        }

        os_log(.info, log: .subscription, "[PurchaseManager] updatePurchasedProducts fetched %d active subscriptions", purchasedSubscriptions.count)

        if self.purchasedProductIDs != purchasedSubscriptions {
            self.purchasedProductIDs = purchasedSubscriptions
        }

        subscriptionGroupStatus = try? await availableProducts.first?.subscription?.status.first?.state
    }

    @MainActor
    public static func mostRecentTransaction() async -> String? {
        os_log(.info, log: .subscription, "[PurchaseManager] mostRecentTransaction")

        var transactions: [VerificationResult<Transaction>] = []

        for await result in Transaction.all {
            transactions.append(result)
        }

        os_log(.info, log: .subscription, "[PurchaseManager] mostRecentTransaction fetched %d transactions", transactions.count)

        return transactions.first?.jwsRepresentation
    }

    @MainActor
    public static func hasActiveSubscription() async -> Bool {
        os_log(.info, log: .subscription, "[PurchaseManager] hasActiveSubscription")

        var transactions: [VerificationResult<Transaction>] = []

        for await result in Transaction.currentEntitlements {
            transactions.append(result)
        }

        os_log(.info, log: .subscription, "[PurchaseManager] hasActiveSubscription fetched %d transactions", transactions.count)

        return !transactions.isEmpty
    }

    @MainActor
    public func purchaseSubscription(with identifier: String, externalID: String) async -> Result<Void, Error> {

        guard let product = availableProducts.first(where: { $0.id == identifier }) else { return .failure(PurchaseManagerError.productNotFound) }

        os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription %{public}s (%{public}s)", product.displayName, externalID)

        purchaseQueue.append(product.id)

        var options: Set<Product.PurchaseOption> = Set()

        if let token = UUID(uuidString: externalID) {
            options.insert(.appAccountToken(token))
        } else {
            os_log(.error, log: .subscription, "[PurchaseManager] Error: Failed to create UUID")
            return .failure(PurchaseManagerError.externalIDisNotAValidUUID)
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch {
            os_log(.error, log: .subscription, "[PurchaseManager] Error: %{public}s", String(reflecting: error))
            return .failure(PurchaseManagerError.purchaseFailed)
        }

        os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription complete")

        purchaseQueue.removeAll()

        switch result {
        case let .success(.verified(transaction)):
            os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription result: success")
            // Successful purchase
            await transaction.finish()
            await self.updatePurchasedProducts()
            return .success(())
        case let .success(.unverified(_, error)):
            os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription result: success /unverified/ - %{public}s", String(reflecting: error))
            // Successful purchase but transaction/receipt can't be verified
            // Could be a jailbroken phone
            return .failure(PurchaseManagerError.transactionCannotBeVerified)
        case .pending:
            os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription result: pending")
            // Transaction waiting on SCA (Strong Customer Authentication) or
            // approval from Ask to Buy
            return .failure(PurchaseManagerError.transactionPendingAuthentication)
        case .userCancelled:
            os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription result: user cancelled")
            return .failure(PurchaseManagerError.purchaseCancelledByUser)
        @unknown default:
            os_log(.info, log: .subscription, "[PurchaseManager] purchaseSubscription result: unknown")
            return .failure(PurchaseManagerError.unknownError)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {

        Task.detached { [unowned self] in
            for await result in Transaction.updates {
                os_log(.info, log: .subscription, "[PurchaseManager] observeTransactionUpdates")

                if case .verified(let transaction) = result {
                    await transaction.finish()
                }

                await self.updatePurchasedProducts()
            }
        }
    }

    private func observeStorefrontChanges() -> Task<Void, Never> {

        Task.detached { [unowned self] in
            for await result in Storefront.updates {
                os_log(.info, log: .subscription, "[PurchaseManager] observeStorefrontChanges: %s", result.countryCode)
                await updatePurchasedProducts()
                await updateAvailableProducts()
            }
        }
    }
}
