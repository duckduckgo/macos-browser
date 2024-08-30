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
    private let accountManager: AccountManager
    private let freemiumPIRUserState: FreemiumPIRUserState

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         userDefaults: UserDefaults = .standard,
         subscriptionAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability(),
         accountManager: AccountManager,
         freemiumPIRUserState: FreemiumPIRUserState) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureDisabler = featureDisabler
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
        self.subscriptionAvailability = subscriptionAvailability
        self.accountManager = accountManager
        self.freemiumPIRUserState = freemiumPIRUserState
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

        os_log("Disabling and removing DBP for all users", log: .dataBrokerProtection)
    }
    
    /// Checks PIR prerequisites
    ///
    /// Prerequisites are satisified if either:
    /// 1. The user is an active freemium user
    /// 2. The user has a subscription with valid entitlements
    ///
    /// - Returns: Bool indicating prerequisites are satisfied
    func arePrerequisitesSatisfied() async -> Bool {

        if freemiumPIRUserState.isActiveUser { return true }

        let entitlements = await accountManager.hasEntitlement(forProductName: .dataBrokerProtection,
                                                               cachePolicy: .reloadIgnoringLocalCacheData)
        var hasEntitlements: Bool
        switch entitlements {
        case .success(let value):
            hasEntitlements = value
        case .failure:
            hasEntitlements = false
        }

        let isAuthenticated = accountManager.accessToken != nil

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
            pixelHandler.fire(.gatekeeperEntitlementsInvalid)
            os_log("🔴 DBP feature Gatekeeper: Entitlement check failed", log: .dataBrokerProtection)
        }

        if !isAuthenticatedResult {
            pixelHandler.fire(.gatekeeperNotAuthenticated)
            os_log("🔴 DBP feature Gatekeeper: Authentication check failed", log: .dataBrokerProtection)
        }
    }
}
