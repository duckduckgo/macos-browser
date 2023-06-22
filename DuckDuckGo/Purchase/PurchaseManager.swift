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
@MainActor
final class PurchaseManager: ObservableObject {

    static let productIdentifiers = ["subscription.1week", "subscription.1month", "subscription.1year",
                                     "review.subscription.1week", "review.subscription.1month", "review.subscription.1year",
                                     "iap.cat", "iap.dog", "iap.rabbit",
                                     "monthly.subscription", "three.month.subscription",
                                     "renewable.1month", "test.subscription.region.pl.1month",
                                     "monthly1"]

    static let shared = PurchaseManager()

    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var purchasedProductIDs: [String] = []
    @Published private(set) var purchaseQueue: [String] = []

    @Published private(set) var subscriptionGroupStatus: RenewalState?

    private var transactionUpdates: Task<Void, Never>?
    private var storefrontChanges: Task<Void, Never>?

    init() {
        transactionUpdates = observeTransactionUpdates()
        storefrontChanges = observeStorefrontChanges()
    }

    deinit {
        transactionUpdates?.cancel()
        storefrontChanges?.cancel()
    }

    @MainActor
    func restorePurchases() {
        Task {
            do {
                purchaseQueue.removeAll()

                try await AppStore.sync()
                await updatePurchasedProducts()
                await updateAvailableProducts()
            } catch {
                print(error)
            }
        }
    }

    @MainActor
    func updateAvailableProducts() async {
        print(" -- [PurchaseManager] updateAvailableProducts()")

        do {
            availableProducts = try await Product.products(for: Self.productIdentifiers)
            print(" -- [PurchaseManager] updateAvailableProducts(): fetched \(availableProducts.count) products")
        } catch {
            print("Error updating available products: \(error)")
        }
    }

    private let session = URLSession(configuration: .ephemeral)

    @MainActor
    func sendPurchaseConfirmation(for transaction: Transaction) async {
        print(transaction)

        let transactionString = transaction.debugDescription

        var request = URLRequest(url: URL(string: "https://use-subspoc1.eastus.cloudapp.azure.com/newAppleSubscription")!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = transaction.debugDescription.data(using: .utf8)

        session.dataTask(with: request) { (_, _, error) in
            if error != nil {
                assertionFailure("PurchaseManager: Failed to send the purchase confirmation")
            }
        }.resume()
    }

    @MainActor
    func updatePurchasedProducts() async {
        print(" -- [PurchaseManager] updatePurchasedProducts()")

        var purchasedSubscriptions: [String] = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                guard transaction.productType == .autoRenewable else { continue }
                guard transaction.revocationDate == nil else { continue }

                if let expirationDate = transaction.expirationDate, expirationDate > .now {
                    purchasedSubscriptions.append(transaction.productID)

                    if let token = transaction.appAccountToken {
                        print(" -- [PurchaseManager] updatePurchasedProducts(): \(transaction.productID) -- custom UUID: \(token)" )
                    }
                }
            } catch {
                print("Error updating purchased products: \(error)")
            }
        }

        print(" -- [PurchaseManager] updatePurchasedProducts(): have \(purchasedSubscriptions.count) active subscriptions")
        self.purchasedProductIDs = purchasedSubscriptions
        subscriptionGroupStatus = try? await availableProducts.first?.subscription?.status.first?.state
    }

    @MainActor
    func buy(_ product: Product, customUUID: String) {
        print(" -- [PurchaseManager] buy: \(product.displayName) (customUUID: \(customUUID))")

        purchaseQueue.append(product.id)

        Task {
            print(" -- [PurchaseManager] starting await task")

            var options: Set<Product.PurchaseOption> = Set()

            if let token = UUID(uuidString: customUUID) {
                options.insert(.appAccountToken(token))
            }

            let result = try await product.purchase(options: options)


            print(" -- [PurchaseManager] receiving await task result")
            purchaseQueue.removeAll()

            switch result {
            case let .success(.verified(transaction)):
                // Successful purchase
                await transaction.finish()
                await sendPurchaseConfirmation(for: transaction)
                await self.updatePurchasedProducts()
            case let .success(.unverified(_, error)):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                print("Error: \(error.localizedDescription)")
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {

        Task.detached { [unowned self] in
            for await result in Transaction.updates {
                print(" -- [PurchaseManager] observeTransactionUpdates()")

                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await sendPurchaseConfirmation(for: transaction)
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
