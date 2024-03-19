//
//  DataBrokerProtectionFeatureVisibility.swift
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

protocol DataBrokerProtectionFeatureVisibility {
    func isFeatureVisible() -> Bool
    func disableAndDeleteForAllUsers()
    func disableAndDeleteForWaitlistUsers()
    func isPrivacyProEnabled() -> Bool
    func isEligibleForThankYouMessage() -> Bool
}

struct DefaultDataBrokerProtectionFeatureVisibility: DataBrokerProtectionFeatureVisibility {
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userDefaults: UserDefaults

    @UserDefaultsWrapper(key: .dataBrokerProtectionCleanedUpFromWaitlistToPrivacyPro, defaultValue: false)
    var dataBrokerProtectionCleanedUpFromWaitlistToPrivacyPro: Bool

    /// Temporary code to use while we have both redeem flow for diary study users. Should be removed later
    static var bypassWaitlist = false

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         userDefaults: UserDefaults = .standard) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureDisabler = featureDisabler
        self.pixelHandler = pixelHandler
        self.userDefaults = userDefaults
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

    private var isInternalUser: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    private var isWaitlistBetaActive: Bool {
        return true
        return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlistBetaActive)
    }

    private var isWaitlistEnabled: Bool {
        return true
        return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlist)
    }

    private var isWaitlistUser: Bool {
        DataBrokerProtectionWaitlist().waitlistStorage.isWaitlistUser
    }

    private var wasWaitlistUser: Bool {
        DataBrokerProtectionWaitlist().waitlistStorage.getWaitlistInviteCode() != nil
    }

    func isPrivacyProEnabled() -> Bool {
#if SUBSCRIPTION
        return NSApp.delegateTyped.subscriptionFeatureAvailability.isFeatureAvailable
#else
        return false
#endif

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
}

#endif
