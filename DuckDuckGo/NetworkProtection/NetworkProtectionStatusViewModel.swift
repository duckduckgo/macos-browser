//
//  NetworkProtectionStatusViewModel.swift
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

import SwiftUI
import Combine
import NetworkExtension
import NetworkProtection

/// This view can be shown from any location where we want the user to be able to interact with NetP.
/// This view shows status information about Network Protection, and offers a chance to toggle it ON and OFF.
///
extension NetworkProtectionStatusView {

    /// The view model definition for ``NetworkProtectionStatusView``
    ///
    public final class Model: ObservableObject {
        /// The NetP service.
        ///
        private let controller: TunnelController

        /// The NetP status reporter
        ///
        private let networkProtectionStatusReporter: NetworkProtectionStatusReporter

        /// The object that's in charge of logging errors and other information.
        ///
        private let logger: NetworkProtectionLogger

        /// The `RunLoop` for the timer.
        ///
        private let runLoopMode: RunLoop.Mode?

        private var statusChangeCancellable: AnyCancellable?
        private var connectivityIssuesCancellable: AnyCancellable?
        private var serverInfoCancellable: AnyCancellable?
        private var tunnelErrorMessageCancellable: AnyCancellable?
        private var controllerErrorMessageCancellable: AnyCancellable?

        // MARK: - Feature Image

        var mainImageAsset: NetworkProtectionAsset {
            switch connectionStatus {
            case .connected:
                return .vpnEnabledImage
            case .disconnecting:
                if case .connected = previousConnectionStatus {
                    return .vpnEnabledImage
                } else {
                    return .vpnDisabledImage
                }
            default:
                return .vpnDisabledImage
            }
        }

        // MARK: - Initialization & Deinitialization

        init(controller: TunnelController,
             networkProtectionStatusReporter: NetworkProtectionStatusReporter = DefaultNetworkProtectionStatusReporter(),
             logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger(),
             runLoopMode: RunLoop.Mode? = nil) {

            self.controller = controller
            self.networkProtectionStatusReporter = networkProtectionStatusReporter
            self.logger = logger
            self.runLoopMode = runLoopMode

            connectionStatus = networkProtectionStatusReporter.statusChangePublisher.value
            isHavingConnectivityIssues = networkProtectionStatusReporter.connectivityIssuesPublisher.value
            internalServerAddress = networkProtectionStatusReporter.serverInfoPublisher.value.serverAddress
            internalServerLocation = networkProtectionStatusReporter.serverInfoPublisher.value.serverLocation
            lastTunnelErrorMessage = networkProtectionStatusReporter.tunnelErrorMessagePublisher.value
            lastControllerErrorMessage = networkProtectionStatusReporter.controllerErrorMessagePublisher.value

            // Particularly useful when unit testing with an initial status of our choosing.
            refreshInternalIsRunning()

            subscribeToStatusChanges()
            subscribeToConnectivityIssues()
            subscribeToTunnelErrorMessages()
            subscribeToControllerErrorMessages()
            subscribeToServerInfoChanges()
        }

        deinit {
            stopTimer()
        }

        // MARK: - Subscriptions

        private func subscribeToStatusChanges() {
            statusChangeCancellable = networkProtectionStatusReporter.statusChangePublisher.sink { [weak self] status in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.connectionStatus = status
                }
            }
        }

        private func subscribeToConnectivityIssues() {
            connectivityIssuesCancellable = networkProtectionStatusReporter.connectivityIssuesPublisher.sink { [weak self] isHavingConnectivityIssues in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.isHavingConnectivityIssues = isHavingConnectivityIssues
                }
            }
        }

        private func subscribeToTunnelErrorMessages() {
            tunnelErrorMessageCancellable = networkProtectionStatusReporter.tunnelErrorMessagePublisher.sink { [weak self] errorMessage in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.lastTunnelErrorMessage = errorMessage
                }
            }
        }

        private func subscribeToControllerErrorMessages() {
            controllerErrorMessageCancellable = networkProtectionStatusReporter.controllerErrorMessagePublisher.sink { [weak self] errorMessage in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.lastControllerErrorMessage = errorMessage
                }
            }
        }

        private func subscribeToServerInfoChanges() {
            serverInfoCancellable = networkProtectionStatusReporter.serverInfoPublisher.sink { [weak self] serverInfo in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.internalServerAddress = serverInfo.serverAddress
                    self.internalServerLocation = serverInfo.serverLocation
                }
            }
        }

        // MARK: - ON/OFF Toggle

        private func startTimer() {
            guard timer == nil else {
                return
            }

            refreshTimeLapsed()

            let newTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.refreshTimeLapsed()
            }

            timer = newTimer

            if let runLoopMode = runLoopMode {
                RunLoop.current.add(newTimer, forMode: runLoopMode)
            }
        }

        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        /// Whether NetP is actually running.
        ///
        @Published
        private var internalIsRunning = false {
            didSet {
                if internalIsRunning {
                    startTimer()
                } else {
                    stopTimer()
                }
            }
        }

        private func refreshInternalIsRunning() {
            switch connectionStatus {
            case .connected, .connecting, .reasserting:
                guard internalIsRunning == false else {
                    return
                }

                internalIsRunning = true
            case .disconnected, .disconnecting:
                guard internalIsRunning == true else {
                    return
                }

                internalIsRunning = false
            default:
                break
            }
        }

        /// Convenience binding to be able to both query and toggle NetP.
        ///
        @MainActor
        var isRunning: Binding<Bool> {
            .init {
                self.internalIsRunning
            } set: { newValue in
                guard newValue != self.internalIsRunning else {
                    return
                }

                self.internalIsRunning = newValue

                if newValue {
                    self.startNetworkProtection()
                } else {
                    self.stopNetworkProtection()
                }
            }
        }

        // MARK: - Status & health

        private weak var timer: Timer?

        private var previousConnectionStatus: NetworkProtectionConnectionStatus = .disconnected

        @Published
        private var connectionStatus: NetworkProtectionConnectionStatus = .disconnected {
            didSet {
                previousConnectionStatus = oldValue
                refreshInternalIsRunning()
                refreshTimeLapsed()
            }
        }

        @Published
        private var isHavingConnectivityIssues: Bool = false

        @Published
        private var lastControllerErrorMessage: String?

        @Published
        private var lastTunnelErrorMessage: String?

        /// The description for the current connection status.
        /// When the status is `connected` this description will also show the time lapsed since connection.
        ///
        @Published var timeLapsed = UserText.networkProtectionStatusViewTimerZero

        private func refreshTimeLapsed() {
            switch connectionStatus {
            case .connected(let connectedDate):
                timeLapsed = timeLapsedString(since: connectedDate)
            case .disconnecting:
                timeLapsed = UserText.networkProtectionStatusViewTimerZero
            default:
                timeLapsed = UserText.networkProtectionStatusViewTimerZero
            }
        }

        /// The description for the current connection status.
        /// When the status is `connected` this description will also show the time lapsed since connection.
        ///
        var connectionStatusDescription: String {
            switch connectionStatus {
            case .connected:
                return "\(UserText.networkProtectionStatusConnected) · \(timeLapsed)"
            case .connecting, .reasserting:
                return UserText.networkProtectionStatusConnecting
            case .disconnected, .notConfigured:
                return UserText.networkProtectionStatusDisconnected
            case .disconnecting:
                return UserText.networkProtectionStatusDisconnecting
            case .unknown:
                return UserText.networkProtectionStatusUnknown
            }
        }

        var issueDescription: String? {
            if let lastControllerErrorMessage = lastControllerErrorMessage {
                return lastControllerErrorMessage
            }

            if let lastTunnelErrorMessage = lastTunnelErrorMessage {
                return lastTunnelErrorMessage
            }

            if isHavingConnectivityIssues {
                switch connectionStatus {
                case .reasserting, .connecting, .connected:
                    return UserText.networkProtectionInterruptedReconnecting
                case .disconnecting, .disconnected:
                    return UserText.networkProtectionInterrupted
                default:
                    return nil
                }
            } else {
                return nil
            }
        }

        private func timeLapsedString(since date: Date) -> String {
            let secondsLapsed = Date().timeIntervalSince(date)

            let hours   = Int(secondsLapsed) / 3600
            let minutes = Int(secondsLapsed) / 60 % 60
            let seconds = Int(secondsLapsed) % 60

            return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
        }

        /// The feature status (ON/OFF) right below the main icon.
        ///
        var featureStatusDescription: String {
            switch connectionStatus {
            case .connected, .disconnecting:
                return UserText.networkProtectionStatusViewFeatureOn
            default:
                return UserText.networkProtectionStatusViewFeatureOff
            }
        }

        // MARK: - Server Information

        var showServerDetails: Bool {
            switch connectionStatus {
            case .connected:
                return true
            case .disconnecting:
                if case .connected = previousConnectionStatus {
                    return true
                } else {
                    return false
                }
            default:
                return false
            }
        }

        @Published
        private var internalServerAddress: String?

        var serverAddress: String {
            guard let internalServerAddress = internalServerAddress else {
                return UserText.networkProtectionServerAddressUnknown
            }

            switch connectionStatus {
            case .connected:
                return internalServerAddress
            case .disconnecting:
                if case .connected = previousConnectionStatus {
                    return internalServerAddress
                } else {
                    return UserText.networkProtectionServerAddressUnknown
                }
            default:
                return UserText.networkProtectionServerAddressUnknown
            }
        }

        @Published
        var internalServerLocation: String?

        var serverLocation: String {
            guard let internalServerLocation = internalServerLocation else {
                return UserText.networkProtectionServerLocationUnknown
            }

            switch connectionStatus {
            case .connected:
                return internalServerLocation
            case .disconnecting:
                if case .connected = previousConnectionStatus {
                    return internalServerLocation
                } else {
                    return UserText.networkProtectionServerLocationUnknown
                }
            default:
                return UserText.networkProtectionServerLocationUnknown
            }
        }

        // MARK: - Toggling Network Protection

        /// Start network protection.
        ///
        private func startNetworkProtection() {
            Task { @MainActor in
                do {
                    try await controller.start()
                } catch {
                    logger.log(error)
                    refreshInternalIsRunning()
                }
            }
        }

        /// Stop network protection.
        ///
        private func stopNetworkProtection() {
            Task { @MainActor in
                do {
                    try await controller.stop()
                } catch {
                    logger.log(error)
                    refreshInternalIsRunning()
                }
            }
        }

        // MARK: - Feedback Sharing

        private static let feedbackFormURL = URL(string: "https://form.asana.com/?k=_wNLt6YcT5ILpQjDuW0Mxw&d=137249556945")!

        /// This method provides the standard logic for handling the user's request to share feedback about NetP.
        /// 
        func shareFeedback() {
            NSWorkspace.shared.open(Self.feedbackFormURL)
        }
    }
}
