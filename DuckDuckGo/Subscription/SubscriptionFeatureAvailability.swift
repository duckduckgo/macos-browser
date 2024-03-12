//
//  SubscriptionFeatureAvailability.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppKit

#if SUBSCRIPTION
import Subscription
#endif

#if NETWORK_PROTECTION
import NetworkProtection
#endif

protocol SubscriptionFeatureAvailability {
    func isFeatureAvailable() -> Bool
}

struct DefaultSubscriptionFeatureAvailability: SubscriptionFeatureAvailability {

    let accountManager = NSApp.delegateTyped.subscriptionManager

    func isFeatureAvailable() -> Bool {
#if SUBSCRIPTION_OVERRIDE_ENABLED
        return true
#elseif SUBSCRIPTION
        print("isUserAuthenticated: [\(accountManager.isUserAuthenticated)] | isSubscriptionInternalTestingEnabled: [\(isSubscriptionInternalTestingEnabled)] isInternalUser: [\(isInternalUser)] | isVPNActivated: [\(isVPNActivated)] | isDBPActivated: [\(isDBPActivated)]")
        return accountManager.isUserAuthenticated || (isSubscriptionInternalTestingEnabled && isInternalUser && !isVPNActivated && !isDBPActivated)
#else
        return false
#endif
    }

    private var isSubscriptionInternalTestingEnabled: Bool {
        UserDefaultsWrapper(key: .subscriptionInternalTesting, defaultValue: false).wrappedValue
    }

    private var isInternalUser: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    private var isVPNActivated: Bool {
#if NETWORK_PROTECTION
        return NetworkProtectionKeychainTokenStore().isFeatureActivated
#else
        return false
#endif
    }

    private var isDBPActivated: Bool {
#if DBP
        return DataBrokerProtectionManager.shared.dataManager.fetchProfile(ignoresCache: true) != nil
#else
        return false
#endif
    }
}
