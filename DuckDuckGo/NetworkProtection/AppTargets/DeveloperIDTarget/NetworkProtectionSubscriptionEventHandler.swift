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
import Subscription
import NetworkProtection
import NetworkProtectionUI

final class NetworkProtectionSubscriptionEventHandler {

    private let accountManager: AccountManaging
    private let networkProtectionRedemptionCoordinator: NetworkProtectionCodeRedeeming
    private let networkProtectionTokenStorage: NetworkProtectionTokenStore
    private let networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling
    private let userDefaults: UserDefaults

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
    }

    private lazy var entitlementMonitor = NetworkProtectionEntitlementMonitor()

    private func setUpEntitlementMonitoring() {
        guard AccountManager().isUserAuthenticated else { return }
        let entitlementsCheck = {
            await AccountManager().hasEntitlement(for: .networkProtection, cachePolicy: .reloadIgnoringLocalCacheData)
        }

        Task {
            await entitlementMonitor.start(entitlementCheck: entitlementsCheck) { result in
                switch result {
                case .validEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = false
                case .invalidEntitlement:
                    UserDefaults.netP.networkProtectionEntitlementsExpired = true
                case .error:
                    break
                }
            }
        }
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
        setUpEntitlementMonitoring()
    }

    @objc private func handleAccountDidSignIn() {
        guard accountManager.accessToken != nil else {
            assertionFailure("[NetP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }
        userDefaults.networkProtectionEntitlementsExpired = false
        setUpEntitlementMonitoring()
    }

    @objc private func handleAccountDidSignOut() {
        print("[NetP Subscription] Deleted NetP auth token after signing out from Privacy Pro")

        Task {
            await networkProtectionFeatureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
        }
    }

}

#endif
