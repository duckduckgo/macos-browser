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

import BrowserServicesKit
import Combine
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionUI

protocol NetworkProtectionFeatureVisibility {
    func isNetworkProtectionVisible() -> Bool
    func disableForAllUsers()
    func disableForWaitlistUsers()
}

struct DefaultNetworkProtectionVisibility: NetworkProtectionFeatureVisibility {
    private let featureDisabler: NetworkProtectionFeatureDisabling
    private let featureOverrides: WaitlistBetaOverriding
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
    private let networkProtectionWaitlist = NetworkProtectionWaitlist()
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let defaults: UserDefaults

    var waitlistIsOngoing: Bool {
        isWaitlistEnabled && isWaitlistBetaActive
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(),
         featureOverrides: WaitlistBetaOverriding = DefaultWaitlistBetaOverrides(),
         featureDisabler: NetworkProtectionFeatureDisabling = NetworkProtectionFeatureDisabler(),
         defaults: UserDefaults = .netP,
         log: OSLog = .networkProtection) {

        self.privacyConfigurationManager = privacyConfigurationManager
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.featureDisabler = featureDisabler
        self.featureOverrides = featureOverrides
        self.defaults = defaults
    }

    /// Calculates whether Network Protection is visible.
    /// The following criteria are used:
    ///
    /// 1. If the user has a valid auth token, the feature is visible
    /// 2. If no auth token is found, the feature is visible if the waitlist feature flag is enabled
    ///
    /// Once the waitlist beta has ended, we can trigger a remote change that removes the user's auth token and turn off the waitlist flag, hiding Network Protection from the user.
    func isNetworkProtectionVisible() -> Bool {
        #if APPSTORE
        return isEasterEggUser || (isUserLocaleAllowed && waitlistIsOngoing)
        #else
        return isEasterEggUser || waitlistIsOngoing
        #endif
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

    /// Whether the user is fully onboarded
    /// 
    var isOnboarded: Bool {
        defaults.networkProtectionOnboardingStatus == .completed
    }

    /// A publisher for the onboarding status
    ///
    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> {
        defaults.networkProtectionOnboardingStatusPublisher
    }

    /// Easter egg users can be identified by them being internal users and having an auth token (NetP being activated).
    ///
    private var isEasterEggUser: Bool {
        !isWaitlistUser && networkProtectionFeatureActivation.isFeatureActivated
    }

    /// Whether it's a user with feature access
    private var isEnabledWaitlistUser: Bool {
        isWaitlistUser && waitlistIsOngoing
    }

    /// Waitlist users are users that have the waitlist enabled and active
    ///
    private var isWaitlistUser: Bool {
        networkProtectionWaitlist.waitlistStorage.isWaitlistUser
    }

    /// Waitlist users are users that have the waitlist enabled and active and are invited
    ///
    private var isInvitedWaitlistUser: Bool {
        networkProtectionWaitlist.waitlistStorage.isWaitlistUser && networkProtectionWaitlist.waitlistStorage.isInvited
    }

    private var isWaitlistBetaActive: Bool {
        switch featureOverrides.waitlistActive {
        case .useRemoteValue:
            guard privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(NetworkProtectionSubfeature.waitlistBetaActive) else {
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

    private var isInternalUser: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    func disableForAllUsers() {
        Task {
            await featureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
        }
    }

    func disableForWaitlistUsers() {
        guard isWaitlistUser else {
            return
        }

        Task {
            await featureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
        }
    }
}

#endif
