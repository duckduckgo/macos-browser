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

import Combine
import Common
import Foundation
import Subscription
import NetworkProtection
import NetworkProtectionUI
import os.log

final class NetworkProtectionSubscriptionEventHandler {

    private let subscriptionManager: SubscriptionManager
    private let tunnelController: TunnelController
    private let networkProtectionTokenStorage: NetworkProtectionTokenStore
    private let vpnUninstaller: VPNUninstalling
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(subscriptionManager: SubscriptionManager,
         tunnelController: TunnelController,
         networkProtectionTokenStorage: NetworkProtectionTokenStore = NetworkProtectionKeychainTokenStore(),
         vpnUninstaller: VPNUninstalling,
         userDefaults: UserDefaults = .netP) {
        self.subscriptionManager = subscriptionManager
        self.tunnelController = tunnelController
        self.networkProtectionTokenStorage = networkProtectionTokenStorage
        self.vpnUninstaller = vpnUninstaller
        self.userDefaults = userDefaults

        subscribeToEntitlementChanges()
    }

    private func subscribeToEntitlementChanges() {
        Task {
            switch await subscriptionManager.accountManager.hasEntitlement(forProductName: .networkProtection) {
            case .success(let hasEntitlements):
                Task {
                    await handleEntitlementsChange(hasEntitlements: hasEntitlements)
                }
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
                        Logger.networkProtection.error("Missing entitlements are truly unexpected")
                        return
                    }

                    let hasEntitlements = entitlements.contains { entitlement in
                        entitlement.product == .networkProtection
                    }

                    Task {
                        await self.handleEntitlementsChange(hasEntitlements: hasEntitlements)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func handleEntitlementsChange(hasEntitlements: Bool) async {
        if hasEntitlements {
            UserDefaults.netP.networkProtectionEntitlementsExpired = false
        } else {
            await tunnelController.stop()
            UserDefaults.netP.networkProtectionEntitlementsExpired = true
        }
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
    }

    @objc private func handleAccountDidSignIn() {
        guard subscriptionManager.accountManager.accessToken != nil else {
            assertionFailure("[NetP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }
        userDefaults.networkProtectionEntitlementsExpired = false
    }

    @objc private func handleAccountDidSignOut() {
        print("[NetP Subscription] Deleted NetP auth token after signing out from Privacy Pro")

        Task {
            try? await vpnUninstaller.uninstall(removeSystemExtension: false)
        }
    }

}
