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
         statusReporter: NetworkProtectionStatusReporter? = nil) {

        self.networkProtectionStatusReporter = statusReporter ?? DefaultNetworkProtectionStatusReporter(
            statusObserver: ConnectionStatusObserverThroughSession(),
            serverInfoObserver: ConnectionServerInfoObserverThroughSession(),
            connectionErrorObserver: ConnectionErrorObserverThroughSession())
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: networkProtectionStatusReporter, isForStatusBar: false)
        self.popovers = popovers
        self.pinningManager = pinningManager
        isPinned = pinningManager.isPinned(.networkProtection)

        isHavingConnectivityIssues = networkProtectionStatusReporter.connectivityIssuesPublisher.value
        buttonImage = .image(for: iconPublisher.icon)

        super.init()

        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        setupIconSubscription()
        setupStatusSubscription()
        setupInterruptionSubscription()
    }

    private func setupIconSubscription() {
        iconPublisherCancellable = iconPublisher.$icon.sink { [weak self] icon in
            self?.buttonImage = .image(for: icon)
        }
    }

    private func setupStatusSubscription() {
        statusChangeCancellable = networkProtectionStatusReporter.statusPublisher.sink { [weak self] status in
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
        interruptionCancellable = networkProtectionStatusReporter.connectivityIssuesPublisher.sink { [weak self] isHavingConnectivityIssues in
            guard let self = self else {
                return
            }

            Task { @MainActor in
                self.isHavingConnectivityIssues = isHavingConnectivityIssues
                self.updateVisibility()
            }
        }
    }

    @MainActor
    private func updateVisibility() {
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
