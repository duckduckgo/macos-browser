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

import Foundation
import NetworkProtection
import NetworkProtectionIPC
import Common
import Subscription
import BrowserServicesKit

extension NetworkProtectionDeviceManager {

    @MainActor
    static func create() -> NetworkProtectionDeviceManager {
        let settings = Application.appDelegate.vpnSettings
        let keyStore = NetworkProtectionKeychainKeyStore()
        let tokenStore = NetworkProtectionKeychainTokenStore()
        return NetworkProtectionDeviceManager(environment: settings.selectedEnvironment,
                                              tokenHandler: tokenStore,
                                              keyStore: keyStore,
                                              errorEvents: .networkProtectionAppDebugEvents)
    }
}

extension NetworkProtectionKeychainTokenStore {
    convenience init() {
        self.init(useAccessTokenProvider: true)
    }

    convenience init(useAccessTokenProvider: Bool) {
        let accessTokenProvider: () -> String? = { Application.appDelegate.subscriptionManager.accountManager.accessToken }
        self.init(keychainType: .default,
                  errorEvents: .networkProtectionAppDebugEvents,
                  useAccessTokenProvider: useAccessTokenProvider,
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
        let settings = Application.appDelegate.vpnSettings
        self.init(
            environment: settings.selectedEnvironment,
            tokenHandler: NetworkProtectionKeychainTokenStore(),
            errorEvents: .networkProtectionAppDebugEvents
        )
    }
}
