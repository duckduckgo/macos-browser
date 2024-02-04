//
//  VPNController.swift
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
import NetworkProtectionProxy

/// Starts and stops the VPN proxy component.
///
/// This class looks at the tunnel and the proxy components and their status and settings, and decides based on
/// a number of conditions whether to start the proxy, stop it, or just leave it be.
///
@MainActor
final class VPNProxyLauncher {
    private let tunnelController: NetworkProtectionTunnelController
    private let proxyController: TransparentProxyController
    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

    init(tunnelController: NetworkProtectionTunnelController,
         proxyController: TransparentProxyController,
         notificationCenter: NotificationCenter = .default) {

        self.notificationCenter = notificationCenter
        self.proxyController = proxyController
        self.tunnelController = tunnelController

        subscribeToStatusChanges()
        subscribeToProxySettingChanges()
    }

    // MARK: - Status Changes

    private func subscribeToStatusChanges() {
        notificationCenter.publisher(for: .NEVPNStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: statusChanged(notification:))
            .store(in: &cancellables)
    }

    private func statusChanged(notification: Notification) {
        Task { @MainActor in
            try await startOrStopProxyIfNeeded()
        }
    }

    // MARK: - Proxy Settings Changes

    private func subscribeToProxySettingChanges() {
        proxyController.settings.changePublisher
            .sink(receiveValue: proxySettingChanged(_:))
            .store(in: &cancellables)
    }

    private func proxySettingChanged(_ change: TransparentProxySettings.Change) {
        Task { @MainActor in
            try await startOrStopProxyIfNeeded()
        }
    }

    // MARK: - Auto starting & stopping the proxy component

    private var isControllingProxy = false

    private func startOrStopProxyIfNeeded() async throws {
        if await shouldStartProxy {
            guard !isControllingProxy else {
                return
            }

            isControllingProxy = true
            try await proxyController.start()
            isControllingProxy = false
        } else if await shouldStopProxy {
            guard !isControllingProxy else {
                return
            }

            isControllingProxy = true
            await proxyController.stop()
            isControllingProxy = false
        }
    }

    private var shouldStartProxy: Bool {
        get async {
            // Starting the proxy only when it's required for active features
            // is a product decision.  It may change once we decide the proxy
            // is stable enough to be running at all times.
            await proxyController.status == .disconnected
            && tunnelController.status == .connected
            && proxyController.isRequiredForActiveFeatures
        }
    }

    private var shouldStopProxy: Bool {
        get async {
            // Stopping the proxy when it's not required for active features
            // is a product decision.  It may change once we decide the proxy
            // is stable enough to be running at all times.
            await proxyController.status == .connected
            && (tunnelController.status == .disconnected || !proxyController.isRequiredForActiveFeatures)
        }
    }
}
