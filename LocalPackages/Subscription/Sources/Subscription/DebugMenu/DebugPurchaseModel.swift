//
//  DebugPurchaseModel.swift
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

@available(macOS 12.0, *)
public final class DebugPurchaseModel: ObservableObject {

    var manager: PurchaseManager
    @Published var subscriptions: [SubscriptionRowModel]

    init(manager: PurchaseManager, subscriptions: [SubscriptionRowModel] = []) {
        self.manager = manager
        self.subscriptions = subscriptions
    }

    @MainActor
    func purchase(_ product: Product) {
        print("Attempting purchase: \(product.displayName)")

        Task {
            var externalID: String?

            if let token = AccountManager().accessToken {
                switch await AuthService.validateToken(accessToken: token) {
                case .success(let response):
                    externalID = response.account.externalID
                case .failure(let error):
                    print("Error: \(error)")
                    return
                }
            }

            if let externalID {
                await manager.purchase(product, customUUID: externalID)
            } else {
                switch await AuthService.createAccount() {
                case .success(let response):
                    await manager.purchase(product, customUUID: response.externalID)
                    AccountManager().exchangeTokensAndRefreshEntitlements(with: response.authToken)
                case .failure(let error):
                    print("Error: \(error)")
                    return
                }
            }
        }
    }
}

@available(macOS 12.0, *)
public struct SubscriptionRowModel: Identifiable {
    public var id: String { product.id + String(isPurchased) + String(isBeingPurchased) }

    public let product: Product
    public let isPurchased: Bool
    public let isBeingPurchased: Bool
}
