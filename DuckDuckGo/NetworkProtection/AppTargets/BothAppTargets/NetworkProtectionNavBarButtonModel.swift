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
import NetworkProtectionUI

/// Model for managing the NetP button in the Nav Bar.
///
final class NetworkProtectionNavBarButtonModel: NSObject, ObservableObject {

    private let networkProtectionStatusReporter: NetworkProtectionStatusReporter
    private var status: NetworkProtection.ConnectionStatus = .disconnected
    private let popovers: NavigationBarPopovers

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

    init(popovers: NavigationBarPopovers,
         pinningManager: PinningManager = LocalPinningManager.shared,
         statusReporter: NetworkProtectionStatusReporter? = nil,
         iconProvider: IconProvider = NavigationBarIconProvider()) {

        let statusObserver = ConnectionStatusObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                    platformDidWakeNotification: NSWorkspace.didWakeNotification)
        let statusInfoObserver = ConnectionServerInfoObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                            platformDidWakeNotification: NSWorkspace.didWakeNotification)
        let connectionErrorObserver = ConnectionErrorObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter,
                                                                            platformDidWakeNotification: NSWorkspace.didWakeNotification)
        self.networkProtectionStatusReporter = statusReporter ?? DefaultNetworkProtectionStatusReporter(
            statusObserver: statusObserver,
            serverInfoObserver: statusInfoObserver,
            connectionErrorObserver: connectionErrorObserver,
            connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
            controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
        )
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: networkProtectionStatusReporter, iconProvider: iconProvider)
        self.popovers = popovers
        self.pinningManager = pinningManager
        isPinned = pinningManager.isPinned(.networkProtection)

        isHavingConnectivityIssues = networkProtectionStatusReporter.connectivityIssuesObserver.recentValue
        buttonImage = .image(for: iconPublisher.icon)

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
            let viewModel = WaitlistViewModel(waitlist: NetworkProtectionWaitlist.shared)
            if NetworkProtectionWaitlist.shared.waitlistStorage.isInvited && !viewModel.acceptedNetworkProtectionTermsAndConditions {
                self?.buttonImage = NSImage(named: "NetworkProtectionAvailableButton")! // .image(for: icon)
            } else {
                self?.buttonImage = .image(for: icon)
            }
        }
    }

    private func setupStatusSubscription() {
        statusChangeCancellable = networkProtectionStatusReporter.statusObserver.publisher.sink { [weak self] status in
            guard let self = self else {
                return
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
            self.buttonImage = NSImage(named: "NetworkProtectionAvailableButton")! 
            self.updateVisibility()
        }
    }

    @MainActor
    private func updateVisibility() {
        let waitlist = NetworkProtectionWaitlist.shared
        let viewModel = WaitlistViewModel(waitlist: waitlist)

        if waitlist.waitlistStorage.isInvited && !viewModel.acceptedNetworkProtectionTermsAndConditions {
            showButton = true
            return
        }

        guard !isPinned,
              !popovers.isNetworkProtectionPopoverShown else {
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

        pinningManager.togglePinning(for: .networkProtection)
    }
}

extension NetworkProtectionNavBarButtonModel: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        updateVisibility()
    }
}

#endif
