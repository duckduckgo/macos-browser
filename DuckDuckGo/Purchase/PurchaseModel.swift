//
//  PurchaseModel.swift
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

import Combine
import StoreKit

@available(macOS 12.0, *)
public final class PurchaseModel: ObservableObject {

    @Published var subscriptions: [SubscriptionRowModel] 

    init(subscriptions: [SubscriptionRowModel] = []) {
        print(" -- PurchaseModel init --")
        self.subscriptions = subscriptions
    }

    var hasOngoingPurchase: Bool { subscriptions.reduce(false) { $0 || $1.isBeingPurchased } }

    func buy(_ product: Product) {
        print("Buying \(product.displayName)")
    }

}

@available(macOS 12.0, *)
public struct SubscriptionRowModel: Identifiable {
    public var id: String { product.id + String(isPurchased) + String(isBeingPurchased) }

    public let product: Product
    public let isPurchased: Bool
    public let isBeingPurchased: Bool
}
