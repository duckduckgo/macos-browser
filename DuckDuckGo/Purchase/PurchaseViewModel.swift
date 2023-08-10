//
//  PurchaseViewModel.swift
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
public final class PurchaseViewModel: ObservableObject {

    enum State {
        case noEmailProtection
        case authenticating
        case loadingProducts
        case readyToPurchase
        case errorOccurred(error: AccountsService.Error)
    }

    @Published var state: State = .noEmailProtection
    @Published var subscriptions: [SubscriptionRowModel] = []
    @Published var storefrontCountry: String = ""

    @Published var currentEntitlements: [AccountsService.ValidateTokenResponse.Entitlement] = []

    @Published var authServiceToken: String?
    @Published var externalID: String?

    init() {
        print(" -- PurchaseViewModel init --")
    }

    deinit {
        print(" -- PurchaseViewModel deinit --")
    }

    var isAuthenticated: Bool {
        guard let token = authServiceToken else { return false }
        return !token.isEmpty
    }

    var hasOngoingPurchase: Bool { subscriptions.map { $0.isBeingPurchased }.contains(true) }

    var errorReason: String {
        guard case .errorOccurred(let error) = state else { return "Unknown reason" }
        return error.localizedDescription
    }

    var errorDescription: String {
        guard case .errorOccurred(let error) = state else { return "Unknown error" }
        return error.description
    }

    @MainActor
    func loadStorefrontCountry() async {
        storefrontCountry = "Loading..."
        storefrontCountry = await Storefront.current?.countryCode ?? "<unknown>"
    }
}

@available(macOS 12.0, *)
public struct SubscriptionRowModel: Identifiable {
    public var id: String { product.id + String(isPurchased) + String(isBeingPurchased) }

    public let product: Product
    public let isPurchased: Bool
    public let isBeingPurchased: Bool
}
