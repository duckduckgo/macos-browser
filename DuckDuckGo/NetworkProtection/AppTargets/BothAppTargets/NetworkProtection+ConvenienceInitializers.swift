//
//  NetworkProtection+ConvenienceInitializers.swift
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

#if NETWORK_PROTECTION

import Foundation
import NetworkProtection
import NetworkProtectionIPC
import Common

#if SUBSCRIPTION
import Subscription
#endif

extension NetworkProtectionDeviceManager {

    @MainActor
    static func create() -> NetworkProtectionDeviceManager {
        let settings = VPNSettings(defaults: .netP)
        let keyStore = NetworkProtectionKeychainKeyStore()
        let tokenStore = NetworkProtectionKeychainTokenStore()
        return NetworkProtectionDeviceManager(environment: settings.selectedEnvironment,
                                              tokenStore: tokenStore,
                                              keyStore: keyStore,
                                              errorEvents: .networkProtectionAppDebugEvents,
                                              isSubscriptionEnabled: NSApp.delegateTyped.subscriptionFeatureAvailability.isFeatureAvailable)
    }
}

extension NetworkProtectionCodeRedemptionCoordinator {
    convenience init() {
        let settings = VPNSettings(defaults: .netP)
        self.init(environment: settings.selectedEnvironment,
                  tokenStore: NetworkProtectionKeychainTokenStore(),
                  errorEvents: .networkProtectionAppDebugEvents,
                  isSubscriptionEnabled: NSApp.delegateTyped.subscriptionFeatureAvailability.isFeatureAvailable)
    }
}

extension NetworkProtectionKeychainTokenStore {
    convenience init() {
        self.init(isSubscriptionEnabled: NSApp.delegateTyped.subscriptionFeatureAvailability.isFeatureAvailable)
    }

    convenience init(isSubscriptionEnabled: Bool) {
#if SUBSCRIPTION
        let accessTokenProvider: () -> String? = { AccountManager().accessToken }
#else
        let accessTokenProvider: () -> String? = { return nil }
#endif
        self.init(keychainType: .default,
                  errorEvents: .networkProtectionAppDebugEvents,
                  isSubscriptionEnabled: isSubscriptionEnabled,
                  accessTokenProvider: accessTokenProvider)
    }
}

extension NetworkProtectionKeychainKeyStore {
    convenience init() {
        self.init(keychainType: .default,
                  errorEvents: .networkProtectionAppDebugEvents)
    }
}

extension NetworkProtectionLocationListCompositeRepository {
    convenience init() {
        let settings = VPNSettings(defaults: .netP)
        self.init(
            environment: settings.selectedEnvironment,
            tokenStore: NetworkProtectionKeychainTokenStore(),
            errorEvents: .networkProtectionAppDebugEvents,
            isSubscriptionEnabled: NSApp.delegateTyped.subscriptionFeatureAvailability.isFeatureAvailable
        )
    }
}

extension TunnelControllerIPCClient {

    convenience init() {
        self.init(machServiceName: Bundle.main.vpnMenuAgentBundleId) { ipcClient in
            Task { @MainActor in
                try await Task.sleep(interval: .seconds(1))

                let featureVisibility = DefaultNetworkProtectionVisibility()
                let isEnabled: Bool

                do {
                    // We want the login item to launch if the VPN should be working but isn't.
                    isEnabled = try await featureVisibility.isFeatureEnabled()
                } catch {
                    // As a fallback if there's an error checking feature visibility,
                    // we want to reconnect to XPC is the login item is installed.
                    isEnabled = featureVisibility.isInstalled
                }

                if isEnabled {
                    // By calling register we make sure that XPC will connect as soon as it
                    // becomes available again, as requests are queued.  This helps ensure
                    // that the client app will always be connected to XPC.
                    ipcClient.register()
                }
            }
        }
    }
}

#endif
