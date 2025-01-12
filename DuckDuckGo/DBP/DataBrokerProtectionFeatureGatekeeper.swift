//
//  DataBrokerProtectionFeatureGatekeeper.swift
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
import BrowserServicesKit
import Common
import DataBrokerProtection
import Subscription
import os.log
import Freemium

protocol DataBrokerProtectionFeatureGatekeeper {
    func disableAndDeleteForAllUsers()
    func arePrerequisitesSatisfied() async -> Bool
}

struct DefaultDataBrokerProtectionFeatureGatekeeper: DataBrokerProtectionFeatureGatekeeper {
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults
    private let subscriptionAvailability: SubscriptionFeatureAvailability
    private let subscriptionManager: any SubscriptionManager
    private let freemiumDBPUserStateManager: FreemiumDBPUserStateManager

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         userDefaults: UserDefaults = .standard,
         subscriptionAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability(),
         subscriptionManager: any SubscriptionManager,
         freemiumDBPUserStateManager: FreemiumDBPUserStateManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureDisabler = featureDisabler
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
        self.subscriptionAvailability = subscriptionAvailability
        self.subscriptionManager = subscriptionManager
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
    }

    var isUserLocaleAllowed: Bool {
        var regionCode: String?
        if #available(macOS 13, *) {
            regionCode = Locale.current.region?.identifier
        } else {
            regionCode = Locale.current.regionCode
        }

        if isInternalUser {
            regionCode = "US"
        }

#if DEBUG // Always assume US for debug builds
        regionCode = "US"
#endif
        return (regionCode ?? "US") == "US"
    }

    func disableAndDeleteForAllUsers() {
        featureDisabler.disableAndDelete()

        Logger.dataBrokerProtection.log("Disabling and removing DBP for all users")
    }

    /// Checks DBP prerequisites
    ///
    /// Prerequisites are satisfied if either:
    /// 1. The user is an active freemium user (e.g has activated freemium and is not authenticated)
    /// 2. The user has a subscription with valid entitlements
    ///
    /// - Returns: Bool indicating prerequisites are satisfied
    func arePrerequisitesSatisfied() async -> Bool {

        let isAuthenticated = subscriptionManager.isUserAuthenticated
        if !isAuthenticated && freemiumDBPUserStateManager.didActivate { return true }

        let hasEntitlements = await subscriptionManager.isFeatureActive(.dataBrokerProtection)
        firePrerequisitePixelsAndLogIfNecessary(hasEntitlements: hasEntitlements, isAuthenticatedResult: isAuthenticated)
        return hasEntitlements && isAuthenticated
    }
}

private extension DefaultDataBrokerProtectionFeatureGatekeeper {

    var isInternalUser: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    func firePrerequisitePixelsAndLogIfNecessary(hasEntitlements: Bool, isAuthenticatedResult: Bool) {
        if !hasEntitlements {
            Logger.dataBrokerProtection.log("DBP feature Gatekeeper: No Entitlements available")
        }

        if !isAuthenticatedResult {
            Logger.dataBrokerProtection.error("DBP feature Gatekeeper: Authentication check failed")
        }
    }
}
