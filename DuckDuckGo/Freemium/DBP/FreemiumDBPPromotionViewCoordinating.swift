//
//  FreemiumDBPPromotionViewCoordinating.swift
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

import Combine
import Foundation
import Freemium
import OSLog

/// Protocol defining the interface for coordinating the visibility and interaction with the
/// Freemium DBP (Data Broker Protection) promotion view.
@MainActor
protocol FreemiumDBPPromotionViewCoordinating: ObservableObject {
    /// A boolean value indicating whether the home page promotion is visible.
    var isHomePagePromotionVisible: Bool { get set }

    /// The view model for the promotion view, determining its contents and actions.
    var viewModel: PromotionViewModel { get }
}

/// Default implementation of `FreemiumDBPPromotionViewCoordinating`, responsible for managing
/// the visibility of the promotion and responding to user interactions with the promotion view.
final class FreemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinating {

    /// Published property that determines whether the promotion is visible on the home page.
    @Published var isHomePagePromotionVisible: Bool = false

    /// The view model representing the promotion, which updates based on the user's state.
    var viewModel: PromotionViewModel {
        createViewModel()
    }

    /// Stores whether the user has dismissed the home page promotion.
    private var didDismissHomePagePromotion: Bool {
        get {
            return freemiumDBPUserStateManager.didDismissHomePagePromotion
        }
        set {
            Logger.freemiumDBP.debug("[Freemium DBP] Promotion dismiss state set to \(newValue)")
            freemiumDBPUserStateManager.didDismissHomePagePromotion = newValue
            isHomePagePromotionVisible = !newValue
        }
    }

    /// The user state manager, which tracks the user's onboarding status and scan results.
    private var freemiumDBPUserStateManager: FreemiumDBPUserStateManager

    /// Responsible for determining the availability of Freemium DBP.
    private let freemiumDBPFeature: FreemiumDBPFeature

    /// The presenter used to show the Freemium DBP UI.
    private let freemiumDBPPresenter: FreemiumDBPPresenter

    /// A set of cancellables for managing Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// The `NotificationCenter` instance used when subscribing to notifications
    private let notificationCenter: NotificationCenter

    /// Initializes the coordinator with the necessary dependencies.
    ///
    /// - Parameters:
    ///   - freemiumDBPUserStateManager: Manages the user's state in the Freemium DBP system.
    ///   - freemiumDBPFeature: The feature that determines the availability of DBP.
    ///   - freemiumDBPPresenter: The presenter used to show the Freemium DBP UI. Defaults to `DefaultFreemiumDBPPresenter`.
    ///   - notificationCenter: The `NotificationCenter` instance used when subscribing to notifications
    init(freemiumDBPUserStateManager: FreemiumDBPUserStateManager,
         freemiumDBPFeature: FreemiumDBPFeature,
         freemiumDBPPresenter: FreemiumDBPPresenter = DefaultFreemiumDBPPresenter(),
         notificationCenter: NotificationCenter = .default) {

        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
        self.freemiumDBPFeature = freemiumDBPFeature
        self.freemiumDBPPresenter = freemiumDBPPresenter
        self.notificationCenter = notificationCenter

        setInitialPromotionVisibilityState()
        subscribeToFeatureAvailabilityUpdates()
        observeFreemiumDBPNotifications()
    }
}

private extension FreemiumDBPPromotionViewCoordinator {

    /// Action to be executed when the user proceeds with the promotion (e.g opens DBP)
    var proceedAction: () -> Void {
        { [weak self] in
            self?.markUserAsOnboarded()
            self?.showFreemiumDBP()
            self?.dismissHomePagePromotion()
        }
    }

    /// Action to be executed when the user closes the promotion.
    var closeAction: () -> Void {
        { [weak self] in
            self?.dismissHomePagePromotion()
        }
    }

    /// Marks the user as onboarded in the Freemium DBP system.
    func markUserAsOnboarded() {
        freemiumDBPUserStateManager.didOnboard = true
    }

    /// Shows the Freemium DBP user interface via the presenter.
    func showFreemiumDBP() {
        freemiumDBPPresenter.showFreemiumDBP(
            didOnboard: freemiumDBPUserStateManager.didOnboard,
            windowControllerManager: WindowControllersManager.shared
        )
    }

    /// Dismisses the home page promotion and updates the user state to reflect this.
    func dismissHomePagePromotion() {
        didDismissHomePagePromotion = true
    }

    /// Sets the initial visibility state of the promotion based on whether the promotion was
    /// previously dismissed and whether the Freemium DBP feature is available.
    func setInitialPromotionVisibilityState() {
        isHomePagePromotionVisible = (!didDismissHomePagePromotion && freemiumDBPFeature.isAvailable)
    }

    /// Creates the view model for the promotion, updating based on the user's scan results.
    ///
    /// - Returns: The `PromotionViewModel` that represents the current state of the promotion.
    func createViewModel() -> PromotionViewModel {
        if let results = freemiumDBPUserStateManager.firstScanResults {
            if results.matchesCount > 0 {
                return .freemiumDBPPromotionScanEngagementResults(
                    resultCount: results.matchesCount,
                    brokerCount: results.brokerCount,
                    proceedAction: proceedAction,
                    closeAction: closeAction
                )
            } else {
                return .freemiumDBPPromotionScanEngagementNoResults(
                    proceedAction: proceedAction,
                    closeAction: closeAction
                )
            }
        } else {
            return .freemiumDBPPromotion(proceedAction: proceedAction, closeAction: closeAction)
        }
    }

    /// Subscribes to feature availability updates from the `freemiumDBPFeature`'s availability publisher.
    ///
    /// This method listens to the `isAvailablePublisher` of the `freemiumDBPFeature`, which publishes
    /// changes to the feature's availability. It performs the following actions when an update is received:
    func subscribeToFeatureAvailabilityUpdates() {
        freemiumDBPFeature.isAvailablePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                guard let self else { return }
                isHomePagePromotionVisible = (!didDismissHomePagePromotion && isAvailable)
            }
            .store(in: &cancellables)
    }

    /// Observes notifications related to Freemium DBP (e.g., result polling complete or entry point activated),
    /// and updates the promotion visibility state accordingly.
    func observeFreemiumDBPNotifications() {
        notificationCenter.publisher(for: .freemiumDBPResultPollingComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.freemiumDBP.debug("[Freemium DBP] Received Scan Results Notification")
                self?.didDismissHomePagePromotion = false
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .freemiumDBPEntryPointActivated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.freemiumDBP.debug("[Freemium DBP] Received Entry Point Activation Notification")
                self?.didDismissHomePagePromotion = true
            }
            .store(in: &cancellables)
    }
}
