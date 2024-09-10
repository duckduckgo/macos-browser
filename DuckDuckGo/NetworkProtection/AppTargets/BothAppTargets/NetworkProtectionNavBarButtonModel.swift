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
    private var status: NetworkProtection.ConnectionStatus = .default
    private let popoverManager: NetPPopoverManager

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - VPN

    private let vpnGatekeeper: VPNFeatureGatekeeper
    private let iconPublisher: NetworkProtectionIconPublisher
    private var iconPublisherCancellable: AnyCancellable?

    // MARK: - Button appearance

    private let pinningManager: PinningManager

    @Published
    private(set) var showVPNButton = false {
        didSet {
            shortcutTitle = pinningManager.shortcutTitle(for: .networkProtection)
        }
    }

    @Published
    private(set) var shortcutTitle: String

    @Published
    private(set) var buttonImage: NSImage?

    var isPinned: Bool {
        pinningManager.isPinned(.networkProtection)
    }

    // MARK: - NetP State

    private var isHavingConnectivityIssues = false

    // MARK: - Initialization

    init(popoverManager: NetPPopoverManager,
         pinningManager: PinningManager = LocalPinningManager.shared,
         vpnGatekeeper: VPNFeatureGatekeeper = DefaultVPNFeatureGatekeeper(subscriptionManager: Application.appDelegate.subscriptionManager),
         statusReporter: NetworkProtectionStatusReporter,
         iconProvider: IconProvider = NavigationBarIconProvider()) {

        self.popoverManager = popoverManager
        self.vpnGatekeeper = vpnGatekeeper
        self.networkProtectionStatusReporter = statusReporter
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: networkProtectionStatusReporter, iconProvider: iconProvider)
        self.pinningManager = pinningManager
        self.shortcutTitle = pinningManager.shortcutTitle(for: .networkProtection)

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
    }

    private func setupIconSubscription() {
        iconPublisherCancellable = iconPublisher.$icon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in
                self?.buttonImage = .image(for: icon)!
            }
    }

    private func setupStatusSubscription() {
        networkProtectionStatusReporter.statusObserver.publisher.sink { [weak self] status in
            guard let self = self else {
                return
            }

            Task { @MainActor in
                self.status = status
                self.updateVisibility()
            }
        }.store(in: &cancellables)
    }

    private func setupInterruptionSubscription() {
        networkProtectionStatusReporter.connectivityIssuesObserver.publisher.sink { [weak self] isHavingConnectivityIssues in
            guard let self = self else {
                return
            }

            Task { @MainActor in
                self.isHavingConnectivityIssues = isHavingConnectivityIssues
                self.updateVisibility()
            }
        }.store(in: &cancellables)
    }

    @MainActor
    func updateVisibility() {
        guard !isPinned,
              !popoverManager.isShown,
              !isHavingConnectivityIssues else {

            pinNetworkProtectionToNavBarIfNeverPinnedBefore()
            showVPNButton = true
            return
        }

        showVPNButton = false
    }

    // MARK: - Pinning

    @objc
    func togglePin() {
        pinningManager.togglePinning(for: .networkProtection)
    }

    /// We want to pin the VPN to the navigation bar the first time it's enabled, and only
    /// if the user hasn't toggled it manually before.
    /// 
    private func pinNetworkProtectionToNavBarIfNeverPinnedBefore() {
        guard !pinningManager.isPinned(.networkProtection),
              !pinningManager.wasManuallyToggled(.networkProtection) else {
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
