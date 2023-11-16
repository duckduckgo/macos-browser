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

import Foundation
import BrowserServicesKit
import Common

protocol DataBrokerProtectionFeatureVisibility {
    func isFeatureVisible() -> Bool
    func disableAndDeleteForAllUsers()
    func disableAndDeleteForWaitlistUsers()
}

struct DefaultDataBrokerProtectionFeatureVisibility: DataBrokerProtectionFeatureVisibility {
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let featureDisabler: DataBrokerProtectionFeatureDisabling

    /// Temporary code to use while we have both redeem flow for diary study users. Should be removed later
    static var bypassWaitlist = false

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler()) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureDisabler = featureDisabler
    }

    var waitlistIsOngoing: Bool {
        isWaitlistEnabled && isWaitlistBetaActive
    }

    private var isUserLocaleAllowed: Bool {
        var regionCode: String?
        if #available(macOS 13, *) {
            regionCode = Locale.current.region?.identifier
        } else {
            regionCode = Locale.current.regionCode
        }

        #if DEBUG // Always assume US for debug builds
        regionCode = "US"
        #endif

        return (regionCode ?? "US") == "US"
    }

    private var isWaitlistBetaActive: Bool {
        // Check privacy config
        // return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlistBetaActive)
        true
    }

    private var isWaitlistEnabled: Bool {
        // Check privacy config
        // return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.waitlist)
        true
    }

    private var isWaitlistUser: Bool {
        DataBrokerProtectionWaitlist().waitlistStorage.isWaitlistUser
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

    /// If we want to prevent new users from joining the waitlist while still allowing waitlist users to continue using it,
    /// we should set isWaitlistEnabled to false and isWaitlistBetaActive to true.
    /// To remove it from everyone, isWaitlistBetaActive should be set to false
    func isFeatureVisible() -> Bool {
        guard isUserLocaleAllowed else { return false }

        if isWaitlistUser {
            return isWaitlistBetaActive
        } else {
            return isWaitlistEnabled && isWaitlistBetaActive
        }
    }
}
