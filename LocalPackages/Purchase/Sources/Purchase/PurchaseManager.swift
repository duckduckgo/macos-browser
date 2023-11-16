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

@available(macOS 12.0, *) typealias Transaction = StoreKit.Transaction
@available(macOS 12.0, *) typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
@available(macOS 12.0, *) typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

@available(macOS 12.0, *)
public final class PurchaseManager: ObservableObject {

    static let productIdentifiers = ["subscription.1week", "subscription.1month", "subscription.1year",
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
    public func hasProductsAvailable() async -> Bool {
        do {
            let availableProducts = try await Product.products(for: Self.productIdentifiers)
            print(" -- [PurchaseManager] updateAvailableProducts(): fetched \(availableProducts.count)")
            return !availableProducts.isEmpty
        } catch {
            print("Error fetching available products: \(error)")
            return false
        }
    }

    @MainActor
    public func restorePurchases() async {
        do {
            purchaseQueue.removeAll()

            print("Before AppStore.sync()")

            try await AppStore.sync()

            print("After AppStore.sync()")

            await updatePurchasedProducts()
            await updateAvailableProducts()
        } catch {
            print("AppStore.sync error: \(error)")
        }
    }

    @MainActor
    public func updateAvailableProducts() async {
        print(" -- [PurchaseManager] updateAvailableProducts()")

        do {
            let availableProducts = try await Product.products(for: Self.productIdentifiers)
            print(" -- [PurchaseManager] updateAvailableProducts(): fetched \(availableProducts.count) products")

            if self.availableProducts != availableProducts {
                print("availableProducts changed!")
                self.availableProducts = availableProducts
            }
        } catch {
            print("Error updating available products: \(error)")
        }
    }

    @MainActor
    func fetchAvailableProducts() async -> [Product] {
        print(" -- [PurchaseManager] fetchAvailableProducts()")

        do {
            let availableProducts = try await Product.products(for: Self.productIdentifiers)
            print(" -- [PurchaseManager] fetchAvailableProducts(): fetched \(availableProducts.count) products")

            return availableProducts
        } catch {
            print("Error fetching available products: \(error)")
            return []
        }
    }

    @MainActor
    public func updatePurchasedProducts() async {
        print(" -- [PurchaseManager] updatePurchasedProducts()")

        var purchasedSubscriptions: [String] = []

        do {
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)

                guard transaction.productType == .autoRenewable else { continue }
                guard transaction.revocationDate == nil else { continue }

                if let expirationDate = transaction.expirationDate, expirationDate > .now {
                    purchasedSubscriptions.append(transaction.productID)

                    if let token = transaction.appAccountToken {
                        print(" -- [PurchaseManager] updatePurchasedProducts(): \(transaction.productID) -- custom UUID: \(token)" )
                    }
                }
            }
        } catch {
            print("Error updating purchased products: \(error)")
        }

        print(" -- [PurchaseManager] updatePurchasedProducts(): have \(purchasedSubscriptions.count) active subscriptions")

        if self.purchasedProductIDs != purchasedSubscriptions {
            print("purchasedSubscriptions changed!")
            self.purchasedProductIDs = purchasedSubscriptions
        }

        subscriptionGroupStatus = try? await availableProducts.first?.subscription?.status.first?.state
    }

    @MainActor
    public static func mostRecentTransaction() async -> String? {
        print(" -- [PurchaseManager] mostRecentTransaction()")

        var transactions: [VerificationResult<Transaction>] = []


//        if let result = await Transaction.latest(for: "subscription.1month") {
//            transactions.append(result)
//        }

        for await result in Transaction.all {
            transactions.append(result)
        }

        print(" -- [PurchaseManager] mostRecentTransaction(): fetched \(transactions.count) transactions")

        return transactions.first?.jwsRepresentation
    }

    @MainActor
    public func purchase(_ product: Product, customUUID: String) async -> String {
        print(" -- [PurchaseManager] buy: \(product.displayName) (customUUID: \(customUUID))")

        print("purchaseQueue append!")
        purchaseQueue.append(product.id)

        print(" -- [PurchaseManager] starting purchase")

        var options: Set<Product.PurchaseOption> = Set()

        if let token = UUID(uuidString: customUUID) {
            options.insert(.appAccountToken(token))
        } else {
            print("Wrong UUID")
            return "error"
        }


        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch {
            print("error \(error)")
            return "error"
        }

        print(" -- [PurchaseManager] purchase complete")

        purchaseQueue.removeAll()
        print("purchaseQueue removeAll!")

        switch result {
        case let .success(.verified(transaction)):
            // Successful purchase
            await transaction.finish()
            await self.updatePurchasedProducts()
            return "ok"
        case let .success(.unverified(_, error)):
            // Successful purchase but transaction/receipt can't be verified
            // Could be a jailbroken phone
            print("Error: \(error.localizedDescription)")
            return "error"
        case .pending:
            // Transaction waiting on SCA (Strong Customer Authentication) or
            // approval from Ask to Buy
            break
        case .userCancelled:
            return "cancelled"
        @unknown default:
            return "unknown"
        }

        return "unknown"
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
                print(" -- [PurchaseManager] observeTransactionUpdates()")

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
                print(" -- [PurchaseManager] observeStorefrontChanges(): \(result.countryCode)")
                await updatePurchasedProducts()
                await updateAvailableProducts()
            }
        }
    }
}
