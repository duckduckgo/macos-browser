//
//  SubscriptionManager+StandardConfiguration.swift
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

import Foundation
import Subscription
import Common
import PixelKit
import BrowserServicesKit
import FeatureFlags

extension DefaultSubscriptionManager {

    // Init the SubscriptionManager using the standard dependencies and configuration, to be used only in the dependencies tree root
    public convenience init(featureFlagger: FeatureFlagger? = nil) {
        // MARK: - Configure Subscription
        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)

        let entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: subscriptionUserDefaults,
                                                                 key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                                 settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))
        let accessTokenStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
        let subscriptionEndpointService = DefaultSubscriptionEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let authEndpointService = DefaultAuthEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
        let subscriptionFeatureMappingCache = DefaultSubscriptionFeatureMappingCache(subscriptionEndpointService: subscriptionEndpointService,
                                                                                     userDefaults: subscriptionUserDefaults)

        let accountManager = DefaultAccountManager(accessTokenStorage: accessTokenStorage,
                                                   entitlementsCache: entitlementsCache,
                                                   subscriptionEndpointService: subscriptionEndpointService,
                                                   authEndpointService: authEndpointService)

        let subscriptionFeatureFlagger: FeatureFlaggerMapping<SubscriptionFeatureFlags> = FeatureFlaggerMapping { feature in
            guard let featureFlagger else {
                // With no featureFlagger provided there is no gating of features
                return feature.defaultState
            }

            switch feature {
            case .usePrivacyProUSARegionOverride:
                return (featureFlagger.internalUserDecider.isInternalUser &&
                        subscriptionEnvironment.serviceEnvironment == .staging &&
                        subscriptionUserDefaults.storefrontRegionOverride == .usa)
            case .usePrivacyProROWRegionOverride:
                return (featureFlagger.internalUserDecider.isInternalUser &&
                        subscriptionEnvironment.serviceEnvironment == .staging &&
                        subscriptionUserDefaults.storefrontRegionOverride == .restOfWorld)
            }
        }

        if #available(macOS 12.0, *) {
            let storePurchaseManager = DefaultStorePurchaseManager(subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                                                                   subscriptionFeatureFlagger: subscriptionFeatureFlagger)
            self.init(storePurchaseManager: storePurchaseManager,
                      accountManager: accountManager,
                      subscriptionEndpointService: subscriptionEndpointService,
                      authEndpointService: authEndpointService,
                      subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                      subscriptionEnvironment: subscriptionEnvironment)
        } else {
            self.init(accountManager: accountManager,
                      subscriptionEndpointService: subscriptionEndpointService,
                      authEndpointService: authEndpointService,
                      subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                      subscriptionEnvironment: subscriptionEnvironment)
        }

        accountManager.delegate = self
    }
}

extension DefaultSubscriptionManager: AccountManagerKeychainAccessDelegate {

    public func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError) {
        PixelKit.fire(PrivacyProErrorPixel.privacyProKeychainAccessError(accessType: accessType, accessError: error),
                      frequency: .legacyDailyAndCount)
    }
}
