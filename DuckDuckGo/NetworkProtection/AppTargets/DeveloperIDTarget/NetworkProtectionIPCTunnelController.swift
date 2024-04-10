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

import Common
import Foundation
import NetworkProtection
import NetworkProtectionIPC
import PixelKit

/// VPN tunnel controller through IPC.
///
final class NetworkProtectionIPCTunnelController {

    private let featureVisibility: NetworkProtectionFeatureVisibility
    private let loginItemsManager: LoginItemsManaging
    private let ipcClient: NetworkProtectionIPCClient

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(),
         loginItemsManager: LoginItemsManaging = LoginItemsManager(),
         ipcClient: NetworkProtectionIPCClient) {

        self.featureVisibility = featureVisibility
        self.loginItemsManager = loginItemsManager
        self.ipcClient = ipcClient
    }

    @MainActor
    func start(attemptHandler: VPNStartAttemptHandling = DefaultVPNStartAttemptHandler()) async {
        attemptHandler.begin()

        do {
            guard try await enableLoginItems() else {
                os_log("🔴 IPC Controller refusing to start the VPN menu app.  Not authorized.", log: .networkProtection)
                return
            }

            ipcClient.start()
            attemptHandler.success()
        } catch {
            os_log("🔴 IPC Controller found en error when starting the VPN: \(error)", log: .networkProtection)
            attemptHandler.failure(error)
        }
    }

    @MainActor
    func stop(attemptHandler: VPNStopAttemptHandling) async {
        attemptHandler.begin()

        do {
            guard try await enableLoginItems() else {
                os_log("🔴 IPC Controller refusing to start the VPN.  Not authorized.", log: .networkProtection)
                return
            }

            ipcClient.stop()
            attemptHandler.success()
        } catch {
            os_log("🔴 IPC Controller found en error when starting the VPN: \(error)", log: .networkProtection)
            attemptHandler.failure(error)
        }
    }

    // MARK: - Login Items Manager

    private func enableLoginItems() async throws -> Bool {
        guard try await featureVisibility.canStartVPN() else {
            // We shouldn't enable the menu app is the VPN feature is disabled.
            return false
        }

        try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)
        return true
    }
}

// MARK: - TunnelController Conformance

extension NetworkProtectionIPCTunnelController: TunnelController {

    @MainActor
    func start() async {
        await start(attemptHandler: DefaultVPNStartAttemptHandler())
    }

    @MainActor
    func stop() async {
        await stop(attemptHandler: DefaultVPNStopAttemptHandler())
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
}

// MARK: - Start Attempts

protocol VPNStartAttemptHandling {
    func begin()
    func success()
    func failure(_ error: Error)
}

extension NetworkProtectionIPCTunnelController {

    private enum StartAttempt: PixelKitEventV2 {
        case begin
        case success
        case failure(_ error: Error)

        var name: String {
            switch self {
            case .begin:
                return "netp_browser_start_attempt"

            case .success:
                return "netp_browser_start_success"

            case .failure:
                return "netp_browser_start_failure"
            }
        }

        var parameters: [String: String]? {
            return nil
        }

        var error: Error? {
            switch self {
            case .begin,
                    .success:
                return nil
            case .failure(let error):
                return error
            }
        }
    }

    private class DefaultVPNStartAttemptHandler: VPNStartAttemptHandling {
        private let pixelKit: PixelKit?

        init(pixelKit: PixelKit? = .shared) {
            self.pixelKit = pixelKit
        }

        func begin() {
            pixelKit?.fire(StartAttempt.begin)
        }

        func success() {
            pixelKit?.fire(StartAttempt.success, frequency: .dailyAndContinuous)
        }

        func failure(_ error: Error) {
            pixelKit?.fire(StartAttempt.failure(error), frequency: .dailyAndContinuous)
        }
    }
}

// MARK: - Stop Attempts

protocol VPNStopAttemptHandling {
    func begin()
    func success()
    func failure(_ error: Error)
}

extension NetworkProtectionIPCTunnelController {

    private enum StopAttempt: PixelKitEventV2 {
        case begin
        case success
        case failure(_ error: Error)

        var name: String {
            switch self {
            case .begin:
                return "netp_browser_stop_attempt"

            case .success:
                return "netp_browser_stop_success"

            case .failure:
                return "netp_browser_stop_failure"
            }
        }

        var parameters: [String: String]? {
            return nil
        }

        var error: Error? {
            switch self {
            case .begin,
                    .success:
                return nil
            case .failure(let error):
                return error
            }
        }
    }

    private class DefaultVPNStopAttemptHandler: VPNStopAttemptHandling {
        private let pixelKit: PixelKit?

        init(pixelKit: PixelKit? = .shared) {
            self.pixelKit = pixelKit
        }

        func begin() {
            pixelKit?.fire(StopAttempt.begin)
        }

        func success() {
            pixelKit?.fire(StopAttempt.success, frequency: .dailyAndContinuous)
        }

        func failure(_ error: Error) {
            pixelKit?.fire(StopAttempt.failure(error), frequency: .dailyAndContinuous)
        }
    }
}
