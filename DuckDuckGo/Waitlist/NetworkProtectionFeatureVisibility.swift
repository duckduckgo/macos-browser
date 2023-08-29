//
//  NetworkProtectionFeatureVisibility.swift
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

#if NETWORK_PROTECTION

import Foundation
import BrowserServicesKit
import NetworkProtection

protocol NetworkProtectionFeatureVisibility {
    func isNetworkProtectionVisible() -> Bool
}

struct DefaultNetworkProtectionVisibility: NetworkProtectionFeatureVisibility {

    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
    private let internalUserDecider: InternalUserDecider
    private let featureOverrides: WaitlistBetaOverriding

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(),
         internalUserDecider: InternalUserDecider,
         featureOverrides: WaitlistBetaOverriding = DefaultWaitlistBetaOverrides()) {

        self.privacyConfigurationManager = privacyConfigurationManager
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.internalUserDecider = internalUserDecider
        self.featureOverrides = featureOverrides
    }

    /// Calculates whether Network Protection is visible.
    /// The following criteria are used:
    ///
    /// 1. If the user has a valid auth token, the feature is visible
    /// 2. If no auth token is found, the feature is visible if the waitlist feature flag is enabled
    ///
    /// Once the waitlist beta has ended, we can trigger a remote change that removes the user's auth token and turn off the waitlist flag, hiding Network Protection from the user.
    func isNetworkProtectionVisible() -> Bool {
        isEasterEggUser || isWaitlistUser
    }

    /// Easter egg users can be identified by them being internal users and having an auth token (NetP being activated).
    ///
    private var isEasterEggUser: Bool {
        internalUserDecider.isInternalUser && networkProtectionFeatureActivation.isFeatureActivated
    }

    /// Waitlist users are users that have the waitlist enabled and active
    ///
    private var isWaitlistUser: Bool {
        isWaitlistEnabled && isWaitlistBetaActive
    }

    private var isWaitlistBetaActive: Bool {
        switch featureOverrides.waitlistActive {
        case .useRemoteValue:
            guard privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(NetworkProtectionSubfeature.waitlistBetaActive) else {

                disableNetworkProtectionForExternalUsers()
                return false
            }

            return true
        case .on:
            return true
        case .off:
            return false
        }
    }

    private var isWaitlistEnabled: Bool {
        switch featureOverrides.waitlistEnabled {
        case .useRemoteValue:
            return privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(NetworkProtectionSubfeature.waitlist)
        case .on:
            return true
        case .off:
            return false
        }
    }

    private func disableNetworkProtectionForExternalUsers() {
#if DEBUG
        if internalUserDecider.isInternalUser {
            print("NetP Debug: Internal user detected. Network Protection is still enabled.")
        } else {
            print("NetP Debug: Network Protection was disabled.")
        }
#endif
    }
}

#endif
