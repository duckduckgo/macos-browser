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

#if DBP

import Foundation
import BrowserServicesKit
import Common
import DataBrokerProtection
import Subscription

protocol DataBrokerProtectionFeatureGatekeeper {
    var waitlistIsOngoing: Bool { get }
    func isFeatureVisible() -> Bool
    func disableAndDeleteForAllUsers()
    func disableAndDeleteForWaitlistUsers()
    func isPrivacyProEnabled() -> Bool
    func isEligibleForThankYouMessage() -> Bool
    func cleanUpDBPForPrivacyProIfNecessary() -> Bool
    func arePrerequisitesSatisfied() async -> Bool
}

struct DefaultDataBrokerProtectionFeatureGatekeeper: DataBrokerProtectionFeatureGatekeeper {
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults
    private let waitlistStorage: WaitlistStorage
    private let subscriptionAvailability: SubscriptionFeatureAvailability
    private let accountManager: AccountManaging

    private let dataBrokerProtectionKey = "data-broker-protection.cleaned-up-from-waitlist-to-privacy-pro"

    /// Temporary code to use while we have both redeem flow for diary study users. Should be removed later
    static var bypassWaitlist = false

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         userDefaults: UserDefaults = .standard,
         waitlistStorage: WaitlistStorage = DataBrokerProtectionWaitlist().waitlistStorage,
         subscriptionAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability(),
         accountManager: AccountManaging) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureDisabler = featureDisabler
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
        self.waitlistStorage = waitlistStorage
        self.subscriptionAvailability = subscriptionAvailability
        self.accountManager = accountManager
    }

    var waitlistIsOngoing: Bool {
        isWaitlistEnabled && isWaitlistBetaActive
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

    func isPrivacyProEnabled() -> Bool {
        return subscriptionAvailability.isFeatureAvailable
    }

    func isEligibleForThankYouMessage() -> Bool {
        return wasWaitlistUser && isPrivacyProEnabled()
    }

    func disableAndDeleteForAllUsers() {
        featureDisabler.disableAndDelete()

        os_log("Disabling and removing DBP for all users", log: .dataBrokerProtection)
    }

    func disableAndDeleteForWaitlistUsers() {
        guard isWaitlistUser else {
            return
        }

        os_log("Disabling and removing DBP for waitlist users", log: .dataBrokerProtection)
        featureDisabler.disableAndDelete()
    }

    /// Returns true if a cleanup was performed, false otherwise
    func cleanUpDBPForPrivacyProIfNecessary() -> Bool {
        if isPrivacyProEnabled() && wasWaitlistUser && !dataBrokerProtectionCleanedUpFromWaitlistToPrivacyPro {
            disableAndDeleteForWaitlistUsers()
            dataBrokerProtectionCleanedUpFromWaitlistToPrivacyPro = true
            return true
        } else {
            return false
        }
    }

    /// If we want to prevent new users from joining the waitlist while still allowing waitlist users to continue using it,
    /// we should set isWaitlistEnabled to false and isWaitlistBetaActive to true.
    /// To remove it from everyone, isWaitlistBetaActive should be set to false
    func isFeatureVisible() -> Bool {
        // only US locale should be available
        guard isUserLocaleAllowed else { return false }

        // US internal users should have it available by default
        guard !isInternalUser else { return true }

        if isWaitlistUser {
            return isWaitlistBetaActive
        } else {
            return isWaitlistEnabled && isWaitlistBetaActive
        }
    }

    func arePrerequisitesSatisfied() async -> Bool {
        let entitlements = await accountManager.hasEntitlement(for: .dataBrokerProtection,
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

    var dataBrokerProtectionCleanedUpFromWaitlistToPrivacyPro: Bool {
        get {
            return userDefaults.bool(forKey: dataBrokerProtectionKey)
        }
        nonmutating set {
            userDefaults.set(newValue, forKey: dataBrokerProtectionKey)
        }
    }

    var isInternalUser: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    var isWaitlistBetaActive: Bool {
        return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlistBetaActive)
    }

    var isWaitlistEnabled: Bool {
        return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlist)
    }

    var isWaitlistUser: Bool {
        waitlistStorage.isWaitlistUser
    }

    var wasWaitlistUser: Bool {
        waitlistStorage.getWaitlistInviteCode() != nil
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
#endif
