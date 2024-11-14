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
import UDSHelper
import os.log

/// VPN tunnel controller through IPC.
///
final class NetworkProtectionIPCTunnelController {

    enum RequestError: CustomNSError {
        case notAuthorizedToEnableLoginItem
        case internalLoginItemError(_ error: Error)

        var errorCode: Int {
            switch self {
            case .notAuthorizedToEnableLoginItem: return 0
            case .internalLoginItemError: return 1
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .notAuthorizedToEnableLoginItem:
                return [:]
            case .internalLoginItemError(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    private let featureGatekeeper: VPNFeatureGatekeeper
    private let loginItemsManager: LoginItemsManaging
    private let ipcClient: NetworkProtectionIPCClient
    private let pixelKit: PixelFiring?
    private let errorRecorder: VPNOperationErrorRecorder
    private let knownFailureStore: NetworkProtectionKnownFailureStore

    init(featureGatekeeper: VPNFeatureGatekeeper = DefaultVPNFeatureGatekeeper(subscriptionManager: Application.appDelegate.subscriptionManager),
         loginItemsManager: LoginItemsManaging = LoginItemsManager(),
         ipcClient: NetworkProtectionIPCClient,
         fileManager: FileManager = .default,
         pixelKit: PixelFiring? = PixelKit.shared,
         errorRecorder: VPNOperationErrorRecorder = VPNOperationErrorRecorder(),
         knownFailureStore: NetworkProtectionKnownFailureStore = NetworkProtectionKnownFailureStore()) {

        self.featureGatekeeper = featureGatekeeper
        self.loginItemsManager = loginItemsManager
        self.ipcClient = ipcClient
        self.pixelKit = pixelKit
        self.errorRecorder = errorRecorder
        self.knownFailureStore = knownFailureStore
    }

    // MARK: - Login Items Manager

    private func enableLoginItems() async throws {
        do {
            try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems)
        } catch {
            throw RequestError.internalLoginItemError(error)
        }
    }
}

// MARK: - TunnelController Conformance

extension NetworkProtectionIPCTunnelController: TunnelController {

    @MainActor
    func start() async {
        errorRecorder.beginRecordingIPCStart()
        pixelKit?.fire(StartAttempt.begin)

        func handleFailure(_ error: Error) {
            knownFailureStore.lastKnownFailure = KnownFailure(error)
            errorRecorder.recordIPCStartFailure(error)
            log(error)
            pixelKit?.fire(StartAttempt.failure(error), frequency: .legacyDailyAndCount)
        }

        do {
            guard try await featureGatekeeper.canStartVPN() else {
                throw RequestError.notAuthorizedToEnableLoginItem
            }

            try await enableLoginItems()

            knownFailureStore.reset()

            ipcClient.start { [pixelKit] error in
                if let error {
                    handleFailure(error)
                } else {
                    pixelKit?.fire(StartAttempt.success, frequency: .legacyDailyAndCount)
                }
            }
        } catch {
            handleFailure(error)
        }
    }

    @MainActor
    func stop() async {
        pixelKit?.fire(StopAttempt.begin)

        func handleFailure(_ error: Error) {
            log(error)
            pixelKit?.fire(StopAttempt.failure(error), frequency: .legacyDailyAndCount)
        }

        do {
            try await enableLoginItems()

            ipcClient.stop { [pixelKit] error in
                if let error {
                    handleFailure(error)
                } else {
                    pixelKit?.fire(StopAttempt.success, frequency: .legacyDailyAndCount)
                }
            }
        } catch {
            handleFailure(error)
        }
    }

    func command(_ command: VPNCommand) async throws {
        try await ipcClient.command(command)
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

    private func log(_ error: Error) {
        switch error {
        case RequestError.notAuthorizedToEnableLoginItem:
            Logger.networkProtection.error("IPC Controller not authorized to enable the login item: \(error.localizedDescription)")
        case RequestError.internalLoginItemError(let error):
            Logger.networkProtection.error("IPC Controller found an error while enabling the login item: \(error.localizedDescription)")
        default:
            Logger.networkProtection.error("IPC Controller found an unknown error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Start Attempts: Pixels

extension NetworkProtectionIPCTunnelController {

    enum StartAttempt: PixelKitEventV2 {
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
}

// MARK: - Stop Attempts

extension NetworkProtectionIPCTunnelController {

    enum StopAttempt: PixelKitEventV2 {
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
}
