//
//  PurchaseViewActions.swift
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

@available(macOS 12.0, *)
public final class PurchaseViewActions {

    var manager: PurchaseManager
    weak var model: PurchaseViewModel?

    init(manager: PurchaseManager, model: PurchaseViewModel) {
        print(" -- PurchaseViewActions init --")
        self.manager = manager
        self.model = model
    }

    deinit {
        print(" -- PurchaseViewActions deinit --")
    }

    @MainActor
    func purchase(_ product: Product) {
        guard let model = model else { return }

        print("Purchasing \(product.displayName)")
        manager.purchase(product, customUUID: model.externalID ?? "")
    }

    @MainActor
    func restorePurchases() {
        manager.restorePurchases()
    }

    @MainActor
    func refreshEntitlements() {
        guard let authServiceToken = self.model?.authServiceToken else { return }

        print(" -- [PurchaseViewActions] refreshEntitlements() --")
        Task {
            switch await AccountsService.validateToken(accessToken: authServiceToken) {
            case .success(let response):
                self.model?.externalID = response.account.externalID
                self.model?.currentEntitlements = response.account.entitlements
            case .failure(let error):
                print(error)
            }
        }
    }

    @MainActor
    func signInUsingEmailProtection() {
        Task {
            switch await AccountsService.getAccessToken() {
            case .success(let response):
                self.model?.authServiceToken = response.accessToken
                refreshEntitlements()
            case .failure(let error):
                print(error)
            }
        }
    }

    @MainActor
    func signOut() {
        model?.authServiceToken = nil
        model?.externalID = nil
    }

    @MainActor
    func testPurchaseWithCreatingNewAccount() {
        Task {
            switch await AccountsService.createAccount() {
            case .success(let response):
                print(response)
                self.model?.externalID = response.externalID
                print("Got externalID: \(response.externalID)")
            case .failure(let error):
                print(error)
            }
        }
    }

    @MainActor
    func testSigningInWithUsingAppStoreHistory() {
        Task {
            guard let (payload, signature) = await manager.mostRecentTransaction() else { return }

            switch await AccountsService.storeLogin(payload: payload, signature: signature) {
            case .success(let response):
                model?.authServiceToken = response.authToken
                model?.externalID = response.externalID
            case .failure(let error):
                print(error)
            }
        }
    }
}
