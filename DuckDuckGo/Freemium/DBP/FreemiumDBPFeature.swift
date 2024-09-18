//
//  FreemiumDBPFeature.swift
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
import Combine
import OSLog

/// A protocol that defines the behavior for the Freemium DBP feature.
/// This protocol provides the ability to check the availability of the feature and subscribe to updates
/// from various dependencies, such as privacy configurations and user subscriptions.
protocol FreemiumDBPFeature {

    /// A boolean value indicating whether the Freemium DBP feature is currently available.
    var isAvailable: Bool { get }

    /// A publisher that emits updates when the availability of the Freemium DBP feature changes.
    /// The publisher emits a `Bool` value indicating whether the feature is available.
    var isAvailablePublisher: AnyPublisher<Bool, Never> { get }

    /// Subscribes to updates from dependencies, including privacy configurations and notifications
    /// such as subscription changes, and triggers updates for feature availability accordingly.
    func subscribeToDependencyUpdates()
}

/// The default implementation of the `FreemiumDBPFeature` protocol.
/// This class manages the Freemium Personal Information Removal (DBP) feature, including
/// determining its availability based on privacy configurations and user subscription status.
/// It listens for updates from multiple dependencies, including privacy configurations
/// and subscription changes, and notifies subscribers accordingly.
final class DefaultFreemiumDBPFeature: FreemiumDBPFeature {

    /// A boolean value indicating whether the Freemium DBP feature is currently available.
    ///
    /// The feature is considered available if:
    /// 1. It is enabled in the privacy configuration (`DBPSubfeature.freemium`), and
    /// 2. User is in the experiement treatment cohort
    /// 3. The user is a potential privacy pro subscriber.
    var isAvailable: Bool {
        privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.freemium)
        && experimentManager.isTreatment
        && subscriptionManager.isPotentialPrivacyProSubscriber
    }

    /// A publisher that emits updates when the availability of the Freemium DBP feature changes.
    ///
    /// Subscribers receive updates when changes occur in the privacy configuration or user subscription status.
    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let experimentManager: FreemiumDBPPixelExperimentManaging
    private let subscriptionManager: SubscriptionManager
    private let accountManager: AccountManager
    private var freemiumDBPUserStateManager: FreemiumDBPUserStateManager
    private let notificationCenter: NotificationCenter
    private lazy var featureDisabler: DataBrokerProtectionFeatureDisabling = DataBrokerProtectionFeatureDisabler()

    private let isAvailableSubject = PassthroughSubject<Bool, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initializes a new instance of the `DefaultFreemiumDBPFeature`.
    ///
    /// - Parameters:
    ///   - privacyConfigurationManager: Manages privacy configurations for the app.
    ///   - subscriptionManager: Manages subscriptions for the user.
    ///   - accountManager: Manages user account details.
    ///   - freemiumDBPUserStateManager: Manages the user state for Freemium DBP.
    ///   - notificationCenter: Observes notifications, defaulting to `.default`.
    ///   - featureDisabler: Optional feature disabler. If not provided, the default `DataBrokerProtectionFeatureDisabler` is used.
    init(privacyConfigurationManager: PrivacyConfigurationManaging,
         experimentManager: FreemiumDBPPixelExperimentManaging,
         subscriptionManager: SubscriptionManager,
         accountManager: AccountManager,
         freemiumDBPUserStateManager: FreemiumDBPUserStateManager,
         notificationCenter: NotificationCenter = .default,
         featureDisabler: DataBrokerProtectionFeatureDisabling? = nil) {

        self.privacyConfigurationManager = privacyConfigurationManager
        self.experimentManager = experimentManager
        self.subscriptionManager = subscriptionManager
        self.accountManager = accountManager
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
        self.notificationCenter = notificationCenter

        // Use the provided feature disabler if available, otherwise initialize lazily.
        if let featureDisabler = featureDisabler {
            self.featureDisabler = featureDisabler
        }
    }

    // MARK: - Public Methods

    /// Subscribes to updates from dependencies such as privacy configuration changes and
    /// subscription-related notifications.
    ///
    /// - When the privacy configuration is updated, it checks whether the Freemium DBP feature
    ///   is still available based on the user's subscription status and the current privacy settings.
    /// - When the user's subscription changes, it also triggers a re-evaluation of the feature's availability.
    func subscribeToDependencyUpdates() {
        // Subscribe to privacy configuration updates
        privacyConfigurationManager.updatesPublisher
            .sink { [weak self] in
                guard let self = self else { return }

                let featureAvailable = self.isAvailable
                Logger.freemiumDBP.debug("[Freemium DBP] Privacy Config Updated. Feature Availability = \(featureAvailable)")

                self.isAvailableSubject.send(featureAvailable)

                self.offBoardIfNecessary()
            }
            .store(in: &cancellables)

        // Subscribe to notifications about subscription changes
        notificationCenter.publisher(for: .subscriptionDidChange)
            .sink { [weak self] _ in
                guard let self = self else { return }

                let featureAvailable = self.isAvailable
                Logger.freemiumDBP.debug("[Freemium DBP] Subscription Updated. Feature Availability = \(featureAvailable)")

                self.isAvailableSubject.send(featureAvailable)
            }
            .store(in: &cancellables)
    }
}

private extension DefaultFreemiumDBPFeature {

    /// Returns true IFF:
    ///
    /// 1. The user did activate Freemium DBP
    /// 2. The feature flag is disabled
    /// 3. The user `isPotentialPrivacyProSubscriber` (see definition)
    var shouldDisableAndDelete: Bool {
        guard freemiumDBPUserStateManager.didActivate else { return false }

        return !privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DBPSubfeature.freemium)
        && subscriptionManager.isPotentialPrivacyProSubscriber
    }

    /// This method offboards a Freemium user if the feature flag was disabled
    ///
    /// Offboarding involves:
    /// - Resettting `FreemiumDBPUserStateManager`state
    /// - Disabling and deleting DBP data
    func offBoardIfNecessary() {
        if shouldDisableAndDelete {
            Logger.freemiumDBP.debug("[Freemium DBP] Feature Disabled: Offboarding")
            freemiumDBPUserStateManager.resetAllState()
            featureDisabler.disableAndDelete()
        }
    }
}

extension SubscriptionManager {

    /// Returns true if a user is a "potential" Privacy Pro subscriber. This means:
    ///
    /// 1. Is eligible to purchase
    /// 2. Is not a current subscriber
    var isPotentialPrivacyProSubscriber: Bool {
        isPrivacyProPurchaseAvailable
        && !accountManager.isUserAuthenticated
    }

    private var isPrivacyProPurchaseAvailable: Bool {
        let platform = currentEnvironment.purchasePlatform
        switch platform {
        case .appStore:
            return canPurchase
        case .stripe:
            return true
        }
    }
}
