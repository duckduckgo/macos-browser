//
//  DefaultSubscriptionManager+StandardConfiguration.swift
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
import Networking
import os.log
import BrowserServicesKit
import FeatureFlags
import NetworkProtection

extension DefaultSubscriptionManager {
    // Init the SubscriptionManager using the standard dependencies and configuration, to be used only in the dependencies tree root
    public convenience init(keychainType: KeychainType,
                            environment: SubscriptionEnvironment,
                            featureFlagger: FeatureFlagger? = nil,
                            userDefaults: UserDefaults) {

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let urlSession = URLSession(configuration: configuration,
                                    delegate: SessionDelegate(),
                                    delegateQueue: nil)
        let apiService = DefaultAPIService(urlSession: urlSession)
        let authEnvironment: OAuthEnvironment = environment.serviceEnvironment == .production ? .production : .staging
        let authService = DefaultOAuthService(baseURL: authEnvironment.url, apiService: apiService)
        let tokenStorage = SubscriptionTokenKeychainStorageV2(keychainType: keychainType)
        let legacyAccountStorage = SubscriptionTokenKeychainStorage(keychainType: keychainType)
        let authClient = DefaultOAuthClient(tokensStorage: tokenStorage,
                                            legacyTokenStorage: legacyAccountStorage,
                                            authService: authService)
        apiService.authorizationRefresherCallback = { _ in
            guard let tokenContainer = tokenStorage.tokenContainer else {
                throw OAuthClientError.internalError("Missing refresh token")
            }

            if tokenContainer.decodedAccessToken.isExpired() {
                Logger.OAuth.debug("Refreshing tokens")
                let tokens = try await authClient.getTokens(policy: .localForceRefresh)
                return tokens.accessToken
            } else {
                Logger.general.debug("Trying to refresh valid token, using the old one")
                return tokenContainer.accessToken
            }
        }

        let subscriptionEndpointService = DefaultSubscriptionEndpointService(apiService: apiService,
                                                                             baseURL: environment.serviceEnvironment.url)
//        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)! // main app
//        let subscriptionFeatureMappingCache = DefaultSubscriptionFeatureMappingCache(subscriptionEndpointService: subscriptionEndpointService,
//                                                                                     userDefaults: userDefaults)
        let subscriptionFeatureFlagger: FeatureFlaggerMapping<SubscriptionFeatureFlags> = FeatureFlaggerMapping { feature in
            guard let featureFlagger else {
                // With no featureFlagger provided there is no gating of features
                return feature.defaultState
            }

            switch feature {
            case .isLaunchedROW:
                return featureFlagger.isFeatureOn(.isPrivacyProLaunchedROW)
            case .isLaunchedROWOverride:
                return featureFlagger.isFeatureOn(.isPrivacyProLaunchedROWOverride)
            case .usePrivacyProUSARegionOverride:
                return (featureFlagger.internalUserDecider.isInternalUser &&
                        environment.serviceEnvironment == .staging &&
                        userDefaults.storefrontRegionOverride == .usa)
            case .usePrivacyProROWRegionOverride:
                return (featureFlagger.internalUserDecider.isInternalUser &&
                        environment.serviceEnvironment == .staging &&
                        userDefaults.storefrontRegionOverride == .restOfWorld)
            }
        }
        let pixelHandler: SubscriptionManager.PixelHandler = { type in
            switch type {
            case .deadToken:
                PixelKit.fire(SubscriptionPixels.privacyProDeadTokenDetected)
            }
        }

        if #available(macOS 12.0, *) {
            self.init(storePurchaseManager: DefaultStorePurchaseManager(subscriptionFeatureMappingCache: subscriptionEndpointService,
                                                                        subscriptionFeatureFlagger: subscriptionFeatureFlagger),
                      oAuthClient: authClient,
                      subscriptionEndpointService: subscriptionEndpointService,
//                      subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                      subscriptionEnvironment: environment,
                      subscriptionFeatureFlagger: subscriptionFeatureFlagger,
                      pixelHandler: pixelHandler)
        } else {
            self.init(oAuthClient: authClient,
                      subscriptionEndpointService: subscriptionEndpointService,
//                      subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                      subscriptionEnvironment: environment,
                      subscriptionFeatureFlagger: subscriptionFeatureFlagger,
                      pixelHandler: pixelHandler)
        }
    }
}