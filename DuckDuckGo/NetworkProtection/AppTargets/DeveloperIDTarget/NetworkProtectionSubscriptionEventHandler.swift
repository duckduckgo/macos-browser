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

import Combine
import Foundation
import Subscription
import NetworkProtection
import NetworkProtectionUI

final class NetworkProtectionSubscriptionEventHandler {

    private let accountManager: AccountManaging
    private let networkProtectionRedemptionCoordinator: NetworkProtectionCodeRedeeming
    private let networkProtectionTokenStorage: NetworkProtectionTokenStore
    private let networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(accountManager: AccountManaging = AccountManager(),
         networkProtectionRedemptionCoordinator: NetworkProtectionCodeRedeeming = NetworkProtectionCodeRedemptionCoordinator(),
         networkProtectionTokenStorage: NetworkProtectionTokenStore = NetworkProtectionKeychainTokenStore(),
         networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling = NetworkProtectionFeatureDisabler(),
         userDefaults: UserDefaults = .netP) {
        self.accountManager = accountManager
        self.networkProtectionRedemptionCoordinator = networkProtectionRedemptionCoordinator
        self.networkProtectionTokenStorage = networkProtectionTokenStorage
        self.networkProtectionFeatureDisabler = networkProtectionFeatureDisabler
        self.userDefaults = userDefaults

        subscribeToEntitlementChanges()
    }

    private func subscribeToEntitlementChanges() {
        Task {
            switch await AccountManager().hasEntitlement(for: .networkProtection) {
            case .success(let hasEntitlements):
                handleEntitlementsChange(hasEntitlements: hasEntitlements)
            case .failure:
                break
            }

            NotificationCenter.default
                .publisher(for: .entitlementsDidChange)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    guard let self else {
                        return
                    }

                    guard let entitlements = notification.userInfo?[UserDefaultsCacheKey.subscriptionEntitlements] as? [Entitlement] else {

                        assertionFailure("Missing entitlements are truly unexpected")
                        return
                    }

                    let hasEntitlements = entitlements.contains { entitlement in
                        entitlement.product == .networkProtection
                    }

                    handleEntitlementsChange(hasEntitlements: hasEntitlements)
                }
                .store(in: &cancellables)
        }
    }

    private func handleEntitlementsChange(hasEntitlements: Bool) {
        if hasEntitlements {
            UserDefaults.netP.networkProtectionEntitlementsExpired = false
        } else {
            networkProtectionFeatureDisabler.stop()
            UserDefaults.netP.networkProtectionEntitlementsExpired = true
        }
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
    }

    @objc private func handleAccountDidSignIn() {
        guard accountManager.accessToken != nil else {
            assertionFailure("[NetP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }
        userDefaults.networkProtectionEntitlementsExpired = false
    }

    @objc private func handleAccountDidSignOut() {
        print("[NetP Subscription] Deleted NetP auth token after signing out from Privacy Pro")

        Task {
            await networkProtectionFeatureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
        }
    }

}

#endif
