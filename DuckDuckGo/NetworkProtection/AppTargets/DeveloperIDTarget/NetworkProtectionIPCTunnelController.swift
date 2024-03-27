//
//  NetworkProtectionIPCTunnelController.swift
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

#if NETWORK_PROTECTION

import Common
import Foundation
import NetworkProtection
import NetworkProtectionIPC

final class NetworkProtectionIPCTunnelController: TunnelController {

    private let featureVisibility: NetworkProtectionFeatureVisibility
    private let loginItemsManager: LoginItemsManager
    private let ipcClient: NetworkProtectionIPCClient

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(),
         loginItemsManager: LoginItemsManager = LoginItemsManager(),
         ipcClient: NetworkProtectionIPCClient) {

        self.featureVisibility = featureVisibility
        self.loginItemsManager = loginItemsManager
        self.ipcClient = ipcClient
    }

    @MainActor
    func start() async {
        do {
            guard try await enableLoginItems() else {
                os_log("🔴 IPC Controller refusing to start the VPN menu app.  Not authorized.", log: .networkProtection)
                return
            }

            ipcClient.start()
        } catch {
            os_log("🔴 IPC Controller found en error when starting the VPN: \(error)", log: .networkProtection)
        }
    }

    @MainActor
    func stop() async {
        do {
            guard try await enableLoginItems() else {
                os_log("🔴 IPC Controller refusing to start the VPN.  Not authorized.", log: .networkProtection)
                return
            }

            ipcClient.stop()
        } catch {
            os_log("🔴 IPC Controller found en error when starting the VPN: \(error)", log: .networkProtection)
        }
    }

    /// Queries VPN to know if it's connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    var isConnected: Bool {
        get {
            if case .connected = ipcClient.ipcStatusObserver.recentValue {
                return true
            }

            return false
        }
    }

    // MARK: - Login Items Manager

    private func enableLoginItems() async throws -> Bool {
        guard try await featureVisibility.canStartVPN() else {
            // We shouldn't enable the menu app is the VPN feature is disabled.
            return false
        }

        loginItemsManager.enableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)
        return true
    }
}

#endif
