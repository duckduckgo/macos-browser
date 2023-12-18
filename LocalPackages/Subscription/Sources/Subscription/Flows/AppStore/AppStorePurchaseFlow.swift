//
//  AppStorePurchaseFlow.swift
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

@available(macOS 12.0, iOS 15.0, *)
public final class AppStorePurchaseFlow {

    public enum Error: Swift.Error {
        case noProductsFound
        case activeSubscriptionAlreadyPresent
        case authenticatingWithTransactionFailed
        case accountCreationFailed
        case purchaseFailed
        case missingEntitlements
    }

    public static func subscriptionOptions() async -> Result<SubscriptionOptions, AppStorePurchaseFlow.Error> {
        os_log(.info, log: .subscription, "[AppStorePurchaseFlow] subscriptionOptions")

        let products = PurchaseManager.shared.availableProducts

        let monthly = products.first(where: { $0.id.contains("1month") })
        let yearly = products.first(where: { $0.id.contains("1year") })

        guard let monthly, let yearly else {
            os_log(.error, log: .subscription, "[AppStorePurchaseFlow] Error: noProductsFound")
            return .failure(.noProductsFound)
        }

        let options = [SubscriptionOption(id: monthly.id, cost: .init(displayPrice: monthly.displayPrice, recurrence: "monthly")),
                       SubscriptionOption(id: yearly.id, cost: .init(displayPrice: yearly.displayPrice, recurrence: "yearly"))]

        let features = SubscriptionFeatureName.allCases.map { SubscriptionFeature(name: $0.rawValue) }

        return .success(SubscriptionOptions(platform: SubscriptionPlatformName.macos.rawValue,
                                            options: options,
                                            features: features))
    }

    public static func purchaseSubscription(with subscriptionIdentifier: String, emailAccessToken: String?) async -> Result<Void, AppStorePurchaseFlow.Error> {
        os_log(.info, log: .subscription, "[AppStorePurchaseFlow] purchaseSubscription")

        let accountManager = AccountManager()
        let externalID: String

        // Check for past transactions most recent
        switch await AppStoreRestoreFlow.restoreAccountFromPastPurchase() {
        case .success:
            os_log(.info, log: .subscription, "[AppStorePurchaseFlow] purchaseSubscription -> restoreAccountFromPastPurchase: activeSubscriptionAlreadyPresent")
            return .failure(.activeSubscriptionAlreadyPresent)
        case .failure(let error):
            os_log(.info, log: .subscription, "[AppStorePurchaseFlow] purchaseSubscription -> restoreAccountFromPastPurchase: %{public}s", String(reflecting: error))
            switch error {
            case .subscriptionExpired(let expiredAccountDetails):
                externalID = expiredAccountDetails.externalID
                accountManager.storeAuthToken(token: expiredAccountDetails.authToken)
                accountManager.storeAccount(token: expiredAccountDetails.accessToken, email: expiredAccountDetails.email, externalID: expiredAccountDetails.externalID)
            default:
                // No history, create new account
                switch await AuthService.createAccount(emailAccessToken: emailAccessToken) {
                case .success(let response):
                    externalID = response.externalID

                    if case let .success(accessToken) = await accountManager.exchangeAuthTokenToAccessToken(response.authToken),
                       case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
                        accountManager.storeAuthToken(token: response.authToken)
                        accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
                    }
                case .failure(let error):
                    os_log(.error, log: .subscription, "[AppStorePurchaseFlow] createAccount error: %{public}s", String(reflecting: error))
                    return .failure(.accountCreationFailed)
                }
            }
        }

        // Make the purchase
        switch await PurchaseManager.shared.purchaseSubscription(with: subscriptionIdentifier, externalID: externalID) {
        case .success:
            return .success(())
        case .failure(let error):
            os_log(.error, log: .subscription, "[AppStorePurchaseFlow] purchaseSubscription error: %{public}s", String(reflecting: error))
            AccountManager().signOut()
            return .failure(.purchaseFailed)
        }
    }

    @discardableResult
    public static func completeSubscriptionPurchase() async -> Result<PurchaseUpdate, AppStorePurchaseFlow.Error> {
        os_log(.info, log: .subscription, "[AppStorePurchaseFlow] completeSubscriptionPurchase")

        let result = await AccountManager.checkForEntitlements(wait: 2.0, retry: 20)

        return result ? .success(PurchaseUpdate(type: "completed")) : .failure(.missingEntitlements)
    }
}
