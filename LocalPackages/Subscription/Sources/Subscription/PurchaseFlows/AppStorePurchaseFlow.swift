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
import Purchase
import Account

public final class AppStorePurchaseFlow {

    public enum PurchaseResult {
        case ok
    }

    public enum Error: Swift.Error {
        case noPastTransactions
        case accountCreationUnsuccessful
        case purchaseUnsuccessful
        case somethingWentWrong
    }

    public static func purchaseSubscription(with identifier: String) async -> Result<AppStorePurchaseFlow.PurchaseResult, AppStorePurchaseFlow.Error> {
        if #available(macOS 12.0, *) {
            // Trigger sign in pop-up
            await PurchaseManager.shared.restorePurchases()

            // Get externalID from current account based on past purchases or create a new one
            guard let externalID = await getUsersExternalID() else { return .failure(.accountCreationUnsuccessful) }

            // Make the purchase
            switch await makePurchase(identifier, externalID: externalID) {
            case true:
                return .success(.ok)
            case false:
                return .failure(.purchaseUnsuccessful)
            }
        }

        return .failure(.somethingWentWrong)
    }

    @available(macOS 12.0, *)
    private static func getUsersExternalID() async -> String? {
        var externalID: String?

        // Try fetching most recent
        if let jwsRepresentation = await PurchaseManager.mostRecentTransaction() {
            externalID = await AccountManager().signInByRestoringPastPurchases(from: jwsRepresentation)
        }

        if externalID == "error" {
            print("No past transactions or account or both?")

            switch await AuthService.createAccount() {
            case .success(let response):
                externalID = response.externalID
                _ = await AccountManager().exchangeTokensAndRefreshEntitlements(with: response.authToken)
            case .failure(let error):
                print("Error: \(error)")
                externalID = nil
            }
        }

        return externalID
    }

    @available(macOS 12.0, *)
    private static func makePurchase(_ identifier: String, externalID: String) async -> Bool {
        // rework to wrap and make a purchase with identifier
        if let product = PurchaseManager.shared.availableProducts.first(where: { $0.id == identifier }) {
            let purchaseResult = await PurchaseManager.shared.purchase(product, customUUID: externalID)

            if purchaseResult == "ok" {
                return true
            } else {
                print("Something went wrong, reason: \(purchaseResult)")
                return false
            }
        }

        return false
    }

    @discardableResult
    public static func checkForEntitlements(wait second: Double, retry times: Int) async -> Bool {
        var count = 0
        var hasEntitlements = false

        repeat {
            print("Attempt \(count)")
            hasEntitlements = await !AccountManager().fetchEntitlements().isEmpty

            if hasEntitlements {
                print("Got entitlements!")
                break
            } else {
                count += 1
                try? await Task.sleep(seconds: 2)
            }
        } while !hasEntitlements && count < 15

        return hasEntitlements
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
