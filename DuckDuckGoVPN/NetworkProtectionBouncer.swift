//
//  NetworkProtectionBouncer.swift
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

import Common
import Foundation
import NetworkProtection
import ServiceManagement
import AppKit
import Subscription

/// Class that implements the necessary logic to ensure Network Protection is enabled, or prevent the app from running otherwise.
///
final class NetworkProtectionBouncer {

    /// Simply verifies that the Network Protection feature is enabled and if not, takes care of killing the
    /// current app.
    ///
    func requireAuthenticationOrKillApp() {
#if SUBSCRIPTION
        Task {
            let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
            let result = await accountManager.hasEntitlement(for: .networkProtection, cachePolicy: .reloadIgnoringLocalCacheData)
            switch result {
            case .success(true), .failure:
                return
            case .success(false):
                os_log(.error, log: .networkProtection, "🔴 Stopping: Network Protection not authorized. Missing entitlement.")

                // EXIT_SUCCESS ensures the login item won't relaunch
                // Ref: https://developer.apple.com/documentation/servicemanagement/smappservice/register()
                // See where it mentions:
                //      "If the helper crashes or exits with a non-zero status, the system relaunches it"
                exit(EXIT_SUCCESS)
            }
        }
#else
        let keychainStore = NetworkProtectionKeychainTokenStore(keychainType: .default, errorEvents: nil, isSubscriptionEnabled: false)

        guard keychainStore.isFeatureActivated else {
            os_log(.error, log: .networkProtection, "🔴 Stopping: Network Protection not authorized. Missing token.")

            // EXIT_SUCCESS ensures the login item won't relaunch
            // Ref: https://developer.apple.com/documentation/servicemanagement/smappservice/register()
            // See where it mentions:
            //      "If the helper crashes or exits with a non-zero status, the system relaunches it"
            exit(EXIT_SUCCESS)
        }
#endif
    }
}
