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
import Networking
import os.log

extension DefaultSubscriptionManager {

    // Init the SubscriptionManager using the standard dependencies and configuration, to be used only in the dependencies tree root
    public convenience init() {
//
//
//        //        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
//        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
//        vpnSettings.alignTo(subscriptionEnvironment: subscriptionEnvironment)
//
//        let configuration = URLSessionConfiguration.default
//        configuration.httpCookieStorage = nil
//        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
//        let urlSession = URLSession(configuration: configuration,
//                                    delegate: SessionDelegate(),
//                                    delegateQueue: nil)
//        let apiService = DefaultAPIService(urlSession: urlSession)
//        let authEnvironment: OAuthEnvironment = subscriptionEnvironment.serviceEnvironment == .production ? .production : .staging
//
//        let authService = DefaultOAuthService(baseURL: authEnvironment.url, apiService: apiService)
//
//        // keychain storage
//        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
//        let tokenStorage = SubscriptionTokenKeychainStorageV2(keychainType: .dataProtection(.named(subscriptionAppGroup)))
//        let legacyAccountStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
//
//        let authClient = DefaultOAuthClient(tokensStorage: tokenStorage,
//                                            legacyTokenStorage: legacyAccountStorage,
//                                            authService: authService)
//
//
//        apiService.authorizationRefresherCallback = { _ in
//            guard let tokenContainer = tokenStorage.tokenContainer else {
//                throw OAuthClientError.internalError("Missing refresh token")
//            }
//
//            if tokenContainer.decodedAccessToken.isExpired() {
//                Logger.OAuth.debug("Refreshing tokens")
//                let tokens = try await authClient.getTokens(policy: .localForceRefresh)
//                return tokens.accessToken
//            } else {
//                Logger.general.debug("Trying to refresh valid token, using the old one")
//                return tokenContainer.accessToken
//            }
//        }
//
//        let subscriptionEndpointService = DefaultSubscriptionEndpointService(apiService: apiService,
//                                                                             baseURL: subscriptionEnvironment.serviceEnvironment.url)
//        let pixelHandler: SubscriptionManager.PixelHandler = { type in
//            switch type {
//            case .deadToken:
//                // TODO: add pixel
//                //                Pixel.fire(pixel: .privacyProDeadTokenDetected)
//                break
//            }
//        }
//
//        if #available(macOS 12.0, *) {
//            let storePurchaseManager = DefaultStorePurchaseManager()
//            subscriptionManager = DefaultSubscriptionManager(storePurchaseManager: storePurchaseManager,
//                                                             oAuthClient: authClient,
//                                                             subscriptionEndpointService: subscriptionEndpointService,
//                                                             subscriptionEnvironment: subscriptionEnvironment,
//                                                             pixelHandler: pixelHandler)
//        } else {
//            subscriptionManager = DefaultSubscriptionManager(oAuthClient: authClient,
//                                                             subscriptionEndpointService: subscriptionEndpointService,
//                                                             subscriptionEnvironment: subscriptionEnvironment,
//                                                             pixelHandler: pixelHandler)
//        }

        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let urlSession = URLSession(configuration: configuration,
                                    delegate: SessionDelegate(),
                                    delegateQueue: nil)
        let apiService = DefaultAPIService(urlSession: urlSession)
        let authEnvironment: OAuthEnvironment = subscriptionEnvironment.serviceEnvironment == .production ? .production : .staging

        let authService = DefaultOAuthService(baseURL: authEnvironment.url, apiService: apiService)

        // keychain storage
        let tokenStorage = SubscriptionTokenKeychainStorageV2(keychainType: .dataProtection(.named(subscriptionAppGroup)))
        let legacyAccountStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))

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

        let accessTokenStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
        let subscriptionEndpointService = DefaultSubscriptionEndpointService(apiService: apiService,
                                                                             baseURL: subscriptionEnvironment.serviceEnvironment.url)

        let pixelHandler: SubscriptionManager.PixelHandler = { type in
            switch type {
            case .deadToken:
                // TODO: add pixel
                //                Pixel.fire(pixel: .privacyProDeadTokenDetected)
                break
            }
        }

        if #available(macOS 12.0, *) {
            self.init(storePurchaseManager: DefaultStorePurchaseManager(),
                      oAuthClient: authClient,
                      subscriptionEndpointService: subscriptionEndpointService,
                      subscriptionEnvironment: subscriptionEnvironment,
                      pixelHandler: pixelHandler)
        } else {
            self.init(oAuthClient: authClient,
                      subscriptionEndpointService: subscriptionEndpointService,
                      subscriptionEnvironment: subscriptionEnvironment,
                      pixelHandler: pixelHandler)
        }
    }
}

//extension DefaultSubscriptionManager: AccountManagerKeychainAccessDelegate {
//
//    public func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError) {
//        PixelKit.fire(PrivacyProErrorPixel.privacyProKeychainAccessError(accessType: accessType, accessError: error),
//                      frequency: .legacyDailyAndCount)
//    }
//}
