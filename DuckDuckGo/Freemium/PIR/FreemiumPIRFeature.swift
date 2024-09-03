//
//  FreemiumPIRFeature.swift
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
import BrowserServicesKit
import Subscription
import Freemium

/// Conforming types encapsulate logic relating to the Freemium PIR Feature (e.g Feature Availability etc.)
protocol FreemiumPIRFeature {
    var isAvailable: Bool { get }
}

/// Default implementation of `FreemiumPIRFeature`
final class DefaultFreemiumPIRFeature: FreemiumPIRFeature {

    private let featureFlagger: FeatureFlagger
    private let subscriptionManager: SubscriptionManager
    private let accountManager: AccountManager
    private var freemiumPIRUserStateManager: FreemiumPIRUserStateManager
    private let featureDisabler: DataBrokerProtectionFeatureDisabling

    var isAvailable: Bool {
        /* Freemium PIR availability criteria:
            1. Feature Flag enabled
            2. Privacy Pro Available
            3. Not a current Privacy Pro subscriber
            4. (Temp) In experiment cohort
         */
        featureFlagger.isFeatureOn(.freemiumPIR) // #1
        && isAPotentialPrivacyProSubscriber // #2 & #3
        // TODO: - Also check experiment cohort here
    }

    init(featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
         subscriptionManager: SubscriptionManager,
         accountManager: AccountManager,
         freemiumPIRUserStateManager: FreemiumPIRUserStateManager,
         featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler()) {

        self.featureFlagger = featureFlagger
        self.subscriptionManager = subscriptionManager
        self.accountManager = accountManager
        self.freemiumPIRUserStateManager = freemiumPIRUserStateManager
        self.featureDisabler = featureDisabler

        offBoardIfNecessary()
    }
}

private extension DefaultFreemiumPIRFeature {

    /// Returns true if a user is a "potential" Privacy Pro subscriber. This means:
    ///
    /// 1. Is eligible to purchase
    /// 2. Is not a current subscriber
    var isAPotentialPrivacyProSubscriber: Bool {
        subscriptionManager.isPrivacyProPurchaseAvailable
        && !accountManager.isUserAuthenticated
    }
    
    /// Returns true IFF:
    ///
    /// 1. The user did onboard to Freemium PIR
    /// 2. The feature flag is disabled
    /// 3. The user `isAPotentialPrivacyProSubscriber` (see definition)
    var shouldDisableAndDelete: Bool {
        guard freemiumPIRUserStateManager.didOnboard else { return false }

        return !featureFlagger.isFeatureOn(.freemiumPIR)
        && isAPotentialPrivacyProSubscriber
    }

    /// This method offboards a Freemium user if the feature flag was disabled
    ///
    /// Offboarding involves:
    /// - Resettting `FreemiumPIRUserStateManager`state
    /// - Disabling and deleting PIR data
    func offBoardIfNecessary() {
        if shouldDisableAndDelete {
            freemiumPIRUserStateManager.didOnboard = false
            featureDisabler.disableAndDelete()
        }
    }
}

private extension SubscriptionManager {

    var isPrivacyProPurchaseAvailable: Bool {
        let platform = currentEnvironment.purchasePlatform
        switch platform {
        case .appStore:
            return canPurchase
        case .stripe:
            return true
        }
    }
}
