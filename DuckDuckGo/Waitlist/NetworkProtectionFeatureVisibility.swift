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
import LoginItems
import PixelKit

#if SUBSCRIPTION
import Subscription
#endif

protocol NetworkProtectionFeatureVisibility {
    var isEligibleForThankYouMessage: Bool { get }
    var isInstalled: Bool { get }

    func canStartVPN() async throws -> Bool
    func isVPNVisible() -> Bool
    func isNetworkProtectionBetaVisible() -> Bool
    func shouldUninstallAutomatically() -> Bool
    func disableForAllUsers() async
    func disableForWaitlistUsers()
    @discardableResult
    func disableIfUserHasNoAccess() async -> Bool
}

struct DefaultNetworkProtectionVisibility: NetworkProtectionFeatureVisibility {
    private static var subscriptionAuthTokenPrefix: String { "ddg:" }
    private let featureDisabler: NetworkProtectionFeatureDisabling
    private let featureOverrides: WaitlistBetaOverriding
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
    private let networkProtectionWaitlist = NetworkProtectionWaitlist()
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let defaults: UserDefaults
    let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
    let accountManager: AccountManager

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
        self.accountManager = AccountManager(subscriptionAppGroup: subscriptionAppGroup)
    }

    /// Calculates whether the VPN is visible.
    /// The following criteria are used:
    ///
    /// 1. If the user has a valid auth token, the feature is visible
    /// 2. If no auth token is found, the feature is visible if the waitlist feature flag is enabled
    ///
    /// Once the waitlist beta has ended, we can trigger a remote change that removes the user's auth token and turn off the waitlist flag, hiding the VPN from the user.
    func isNetworkProtectionBetaVisible() -> Bool {
        return isEasterEggUser || waitlistIsOngoing
    }

    var isInstalled: Bool {
        LoginItem.vpnMenu.status.isInstalled
    }

    /// Whether the user can start the VPN.
    ///
    /// For beta users this means they have an auth token.
    /// For subscription users this means they have entitlements.
    ///
    func canStartVPN() async throws -> Bool {
        guard subscriptionFeatureAvailability.isFeatureAvailable else {
            return isNetworkProtectionBetaVisible()
        }

        switch await accountManager.hasEntitlement(for: .networkProtection) {
        case .success(let hasEntitlement):
            return hasEntitlement
        case .failure(let error):
            throw error
        }
    }

    /// Whether the user can see the VPN entry points in the UI.
    ///
    /// For beta users this means they have an auth token.
    /// For subscription users this means they are authenticated.
    ///
    func isVPNVisible() -> Bool {
        guard subscriptionFeatureAvailability.isFeatureAvailable else {
            return isNetworkProtectionBetaVisible()
        }

        return accountManager.isUserAuthenticated
    }

    /// We've had to add this method because accessing the singleton in app delegate is crashing the integration tests.
    ///
    var subscriptionFeatureAvailability: DefaultSubscriptionFeatureAvailability {
        DefaultSubscriptionFeatureAvailability()
    }

    /// Returns whether the VPN should be uninstalled automatically.
    /// This is only true when the user is not an Easter Egg user, the waitlist test has ended, and the user is onboarded.
    func shouldUninstallAutomatically() -> Bool {
#if SUBSCRIPTION
        return subscriptionFeatureAvailability.isFeatureAvailable && !accountManager.isUserAuthenticated && LoginItem.vpnMenu.status.isInstalled
#else
        let waitlistAccessEnded = isWaitlistUser && !waitlistIsOngoing
        let isNotEasterEggUser = !isEasterEggUser
        let isOnboarded = defaults.networkProtectionOnboardingStatus != .default

        return isNotEasterEggUser && waitlistAccessEnded && isOnboarded
#endif
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

    func disableForAllUsers() async {
        await featureDisabler.disable(keepAuthToken: true, uninstallSystemExtension: false)
    }

    /// Disables the VPN for legacy users, if necessary.
    ///
    /// This method does not seek to remove tokens or uninstall anything.
    ///
    private func disableVPNForLegacyUsersIfSubscriptionAvailable() async -> Bool {
        guard isEligibleForThankYouMessage && !defaults.vpnLegacyUserAccessDisabledOnce else {
            return false
        }

        PixelKit.fire(VPNPrivacyProPixel.vpnBetaStoppedWhenPrivacyProEnabled, frequency: .dailyAndContinuous)
        defaults.vpnLegacyUserAccessDisabledOnce = true
        await featureDisabler.disable(keepAuthToken: true, uninstallSystemExtension: false)
        return true
    }

    func disableForWaitlistUsers() {
        guard isWaitlistUser else {
            return
        }

        Task {
            await featureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: false)
        }
    }

    /// A method meant to be called safely from different places to disable the VPN if the user isn't meant to have access to it.
    ///
    @discardableResult
    func disableIfUserHasNoAccess() async -> Bool {
        if shouldUninstallAutomatically() {
            await disableForAllUsers()
            return true
        }

        return await disableVPNForLegacyUsersIfSubscriptionAvailable()
    }

    // MARK: - Subscription Start Support

    /// To query whether we're a legacy (waitlist or easter egg) user.
    ///
    private func isPreSubscriptionUser() -> Bool {
        guard let token = try? NetworkProtectionKeychainTokenStore(isSubscriptionEnabled: false).fetchToken() else {
            return false
        }

        return !token.hasPrefix(Self.subscriptionAuthTokenPrefix)
    }

    /// Checks whether the VPN needs to be disabled.
    ///
    var isEligibleForThankYouMessage: Bool {
        isPreSubscriptionUser() && subscriptionFeatureAvailability.isFeatureAvailable
    }
}

#endif
