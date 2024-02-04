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

/// This is the master controller for the VPN components.
///
/// This class provides a location where all components of the VPN can be monitored.
/// This class takes care of monitoring and operating components that need to be enabled or disabled
/// based on special conditions.
///
@MainActor
final class VPNController {
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

    // MARK: - Auto starting & stopping the proxy component

    var isControllingProxy = false

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
            guard tunnelController.status == .connected else {
                return false
            }

            guard await proxyController.status == .disconnected else {
                return false
            }

            return proxyController.canStart
        }
    }

    private var shouldStopProxy: Bool {
        get async {
            guard tunnelController.status == .disconnected else {
                return false
            }

            return await proxyController.status == .connected
        }
    }
}
