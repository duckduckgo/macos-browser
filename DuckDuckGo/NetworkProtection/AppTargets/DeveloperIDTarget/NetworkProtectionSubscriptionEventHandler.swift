//
//  NetworkProtectionSubscriptionEventHandler.swift
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

#if NETWORK_PROTECTION && SUBSCRIPTION

import Foundation
import Account
import NetworkProtection

final class NetworkProtectionSubscriptionEventHandler {

    private let accountManager: Account.AccountManaging
    private let networkProtectionRedemptionCoordinator: NetworkProtectionCodeRedeeming
    private let networkProtectionTokenStorage: NetworkProtectionTokenStore
    private let networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling

    init(accountManager: Account.AccountManaging = Account.AccountManager(),
         networkProtectionRedemptionCoordinator: NetworkProtectionCodeRedeeming = NetworkProtectionCodeRedemptionCoordinator(),
         networkProtectionTokenStorage: NetworkProtectionTokenStore = NetworkProtectionKeychainTokenStore(),
         networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling = NetworkProtectionFeatureDisabler()) {
        self.accountManager = accountManager
        self.networkProtectionRedemptionCoordinator = networkProtectionRedemptionCoordinator
        self.networkProtectionTokenStorage = networkProtectionTokenStorage
        self.networkProtectionFeatureDisabler = networkProtectionFeatureDisabler
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
    }

    @objc private func handleAccountDidSignIn() {
        guard let token = accountManager.token else {
            assertionFailure("[NetP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }

        // Remove the existing auth token:

        do {
            try networkProtectionTokenStorage.deleteToken()
            print("[NetP Subscription] Removed existing token")
        } catch {
            print("[NetP Subscription] Failed to remove existing token")
        }

        // Get the new auth token:

        Task {
            do {
                try await networkProtectionRedemptionCoordinator.exchange(accessToken: token)
                print("[NetP Subscription] Exchanged access token for auth token successfully")
            } catch {
                print("[NetP Subscription] Failed to exchange access token for auth token: \(error)")
            }
        }
    }

    @objc private func handleAccountDidSignOut() {
        print("[NetP Subscription] Deleted NetP auth token after signing out from Privacy Pro")
        networkProtectionFeatureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
    }

}

#endif
