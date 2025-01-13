//
//  VPNFeatureGatekeeper.swift
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

import BrowserServicesKit
import Combine
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionUI
import LoginItems
import PixelKit
import Subscription

protocol VPNFeatureGatekeeper {
    var isInstalled: Bool { get }

    func canStartVPN() async throws -> Bool
    func isVPNVisible() -> Bool
    func shouldUninstallAutomatically() -> Bool
    func disableIfUserHasNoAccess() async

    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> { get }
}

struct DefaultVPNFeatureGatekeeper: VPNFeatureGatekeeper {
    private static var subscriptionAuthTokenPrefix: String { "ddg:" }
    private let vpnUninstaller: VPNUninstalling
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
    private let defaults: UserDefaults
    private let subscriptionManager: SubscriptionManager

    init(networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(),
         vpnUninstaller: VPNUninstalling = VPNUninstaller(),
         defaults: UserDefaults = .netP,
         subscriptionManager: SubscriptionManager) {

        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.vpnUninstaller = vpnUninstaller
        self.defaults = defaults
        self.subscriptionManager = subscriptionManager
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
        switch await subscriptionManager.accountManager.hasEntitlement(forProductName: .networkProtection) {
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
        subscriptionManager.accountManager.isUserAuthenticated
    }

    /// Returns whether the VPN should be uninstalled automatically.
    /// This is only true when the user is not an Easter Egg user, the waitlist test has ended, and the user is onboarded.
    func shouldUninstallAutomatically() -> Bool {
        !subscriptionManager.accountManager.isUserAuthenticated && LoginItem.vpnMenu.status.isInstalled
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

    /// A method meant to be called safely from different places to disable the VPN if the user isn't meant to have access to it.
    ///
    func disableIfUserHasNoAccess() async {
        guard shouldUninstallAutomatically() else {
            return
        }

        /// There's not much to be done for this error here.
        /// The uninstall call already fires pixels to allow us to anonymously track success rate and see the errors.
        try? await vpnUninstaller.uninstall(removeSystemExtension: false)
    }
}
