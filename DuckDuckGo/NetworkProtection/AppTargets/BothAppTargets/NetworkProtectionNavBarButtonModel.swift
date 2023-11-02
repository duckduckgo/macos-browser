//
//  NetworkProtectionNavBarButtonModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import AppKit
import Combine
import Foundation
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI

/// Model for managing the NetP button in the Nav Bar.
///
final class NetworkProtectionNavBarButtonModel: NSObject, ObservableObject {

    private let networkProtectionStatusReporter: NetworkProtectionStatusReporter
    private var status: NetworkProtection.ConnectionStatus = .disconnected
    private let popoverManager: NetworkProtectionNavBarPopoverManager
    private let waitlistActivationDateStore: DefaultWaitlistActivationDateStore

    // MARK: - IPC

    public var ipcClient: TunnelControllerIPCClient {
        popoverManager.ipcClient
    }

    // MARK: - Subscriptions

    private var statusChangeCancellable: AnyCancellable?
    private var interruptionCancellable: AnyCancellable?

    // MARK: - NetP Icon publisher

    private let iconPublisher: NetworkProtectionIconPublisher
    private var iconPublisherCancellable: AnyCancellable?

    // MARK: - Button appearance

    private let pinningManager: PinningManager

    @Published
    private(set) var showButton = false

    @Published
    private(set) var buttonImage: NSImage?

    var isPinned: Bool {
        didSet {
            Task { @MainActor in
                updateVisibility()
            }
        }
    }

    // MARK: - NetP State

    private var isHavingConnectivityIssues = false

    // MARK: - Initialization

    init(popoverManager: NetworkProtectionNavBarPopoverManager,
         pinningManager: PinningManager = LocalPinningManager.shared,
         statusReporter: NetworkProtectionStatusReporter? = nil,
         iconProvider: IconProvider = NavigationBarIconProvider()) {

        let vpnBundleID = Bundle.main.vpnMenuAgentBundleId
        self.popoverManager = popoverManager

        let ipcClient = popoverManager.ipcClient

        self.networkProtectionStatusReporter = statusReporter
            ?? DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.connectionStatusObserver,
                serverInfoObserver: ipcClient.serverInfoObserver,
                connectionErrorObserver: ipcClient.connectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
        )
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: networkProtectionStatusReporter, iconProvider: iconProvider)
        self.pinningManager = pinningManager
        isPinned = pinningManager.isPinned(.networkProtection)

        isHavingConnectivityIssues = networkProtectionStatusReporter.connectivityIssuesObserver.recentValue
        buttonImage = .image(for: iconPublisher.icon)

        self.waitlistActivationDateStore = DefaultWaitlistActivationDateStore()
        super.init()

        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        setupIconSubscription()
        setupStatusSubscription()
        setupInterruptionSubscription()
        setupWaitlistAvailabilitySubscription()
    }

    private func setupIconSubscription() {
        iconPublisherCancellable = iconPublisher.$icon.sink { [weak self] icon in
            self?.buttonImage = self?.buttonImageFromWaitlistState(icon: icon)
        }
    }

    /// Temporary override used for the NetP waitlist beta, as a different asset is used for users who are invited to join the beta but haven't yet accepted.
    /// This will be removed once the waitlist beta has ended.
    private func buttonImageFromWaitlistState(icon: NetworkProtectionAsset?) -> NSImage {
        let icon = icon ?? iconPublisher.icon

        let isWaitlistUser = NetworkProtectionWaitlist().waitlistStorage.isWaitlistUser
        let hasAuthToken = NetworkProtectionKeychainTokenStore().isFeatureActivated

        if !isWaitlistUser && !hasAuthToken {
            return NSImage(named: "NetworkProtectionAvailableButton")!
        }

        if NetworkProtectionWaitlist().readyToAcceptTermsAndConditions {
            return NSImage(named: "NetworkProtectionAvailableButton")!
        }

        if NetworkProtectionKeychainTokenStore().isFeatureActivated {
            return .image(for: icon)!
        }

        return .image(for: icon)!
    }

    private func setupStatusSubscription() {
        statusChangeCancellable = networkProtectionStatusReporter.statusObserver.publisher.sink { [weak self] status in
            guard let self = self else {
                return
            }

            switch status {
            case .connected:
                waitlistActivationDateStore.setActivationDateIfNecessary()
                waitlistActivationDateStore.updateLastActiveDate()
            default: break
            }

            Task { @MainActor in
                self.status = status
                self.updateVisibility()
            }
        }
    }

    private func setupInterruptionSubscription() {
        interruptionCancellable = networkProtectionStatusReporter.connectivityIssuesObserver.publisher.sink { [weak self] isHavingConnectivityIssues in
            guard let self = self else {
                return
            }

            Task { @MainActor in
                self.isHavingConnectivityIssues = isHavingConnectivityIssues
                self.updateVisibility()
            }
        }
    }

    private func setupWaitlistAvailabilitySubscription() {
        NotificationCenter.default.addObserver(forName: .networkProtectionWaitlistAccessChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in
                self.buttonImage = self.buttonImageFromWaitlistState(icon: nil)
                self.updateVisibility()
            }
        }
    }

    @MainActor
    private func updateVisibility() {
        // The button is visible in the case where NetP has not been activated, but the user has been invited and they haven't accepted T&Cs.
        let networkProtectionVisibility = DefaultNetworkProtectionVisibility()
        if networkProtectionVisibility.isNetworkProtectionVisible() {
            if NetworkProtectionWaitlist().readyToAcceptTermsAndConditions {
                DailyPixel.fire(pixel: .networkProtectionWaitlistEntryPointToolbarButtonDisplayed,
                                frequency: .dailyOnly,
                                includeAppVersionParameter: true)
                showButton = true
                return
            }

            let isWaitlistUser = NetworkProtectionWaitlist().waitlistStorage.isWaitlistUser
            let hasAuthToken = NetworkProtectionKeychainTokenStore().isFeatureActivated

            // If the user hasn't signed up to the waitlist or doesn't have an auth token through some other method, then show them the badged icon
            // to get their attention and encourage them to sign up.
            if !isWaitlistUser && !hasAuthToken {
                showButton = true
                return
            }
        }

        guard !isPinned,
              !popoverManager.isShown else {
            showButton = true
            return
        }

        Task {
            guard !isHavingConnectivityIssues else {
                showButton = true
                return
            }

            switch status {
            case .connecting, .connected, .reasserting, .disconnecting:
                showButton = true

                pinNetworkProtectionToNavBarIfNeverPinnedBefore()
            default:
                showButton = false
            }
        }
    }

    /// We want to pin Network Protection to the navigation bar the first time it's enabled, and only
    /// if the user hasn't toggled it manually before.
    /// 
    private func pinNetworkProtectionToNavBarIfNeverPinnedBefore() {
        assert(showButton)

        guard !pinningManager.wasManuallyToggled(.networkProtection),
              !pinningManager.isPinned(.networkProtection) else {
            return
        }

        pinningManager.pin(.networkProtection)
    }
}

extension NetworkProtectionNavBarButtonModel: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        updateVisibility()
    }
}

#endif
