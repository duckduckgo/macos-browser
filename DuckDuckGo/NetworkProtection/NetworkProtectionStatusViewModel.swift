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
import NetworkExtension

/// This view can be shown from any location where we want the user to be able to interact with NetP.
/// This view shows status information about Network Protection, and offers a chance to toggle it ON and OFF.
///
extension NetworkProtectionStatusView {

    /// The view model definition for ``NetworkProtectionStatusView``
    ///
    public final class Model: ObservableObject {
        /// The NetP service.
        ///
        private let networkProtection: NetworkProtectionProvider

        /// The object that's in charge of logging errors and other information.
        ///
        private let logger: NetworkProtectionLogger

        /// The `RunLoop` for the timer.
        ///
        private let runLoopMode: RunLoop.Mode?

        // MARK: - Feature Image

        var mainImageAsset: NetworkProtectionAsset {
            switch connectionStatus {
            case .connected, .disconnecting:
                return .vpnEnabledImage
            default:
                return .vpnDisabledImage
            }
        }

        // MARK: - Initialization & Deinitialization

        init(networkProtection: NetworkProtectionProvider = NetworkProtectionProvider(),
             logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger(),
             runLoopMode: RunLoop.Mode? = nil) {

            self.networkProtection = networkProtection
            self.logger = logger
            self.runLoopMode = runLoopMode

            networkProtection.onStatusChange = { [weak self] status in
                guard let self = self else {
                    return
                }

                Task { @MainActor in
                    self.connectionStatus = status
                }
            }
        }

        deinit {
            stopTimer()
        }

        // MARK: - ON/OFF Toggle

        func startTimer() {
            guard timer == nil else {
                return
            }

            refreshTimeLapsed()

            let newTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.refreshTimeLapsed()
            }

            timer = newTimer

            if let runLoopMode = runLoopMode {
                RunLoop.current.add(newTimer, forMode: runLoopMode)
            }
        }

        func stopTimer() {
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

        @MainActor
        private func refreshInternalIsRunning() {
            switch connectionStatus {
            case .connected:
                internalIsRunning = true
            case .disconnected:
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

        // MARK: - Status

        weak var timer: Timer?

        @Published
        private var connectionStatus: NetworkProtectionProvider.ConnectionStatus = .disconnected {
            didSet {
                Task { @MainActor in
                    refreshInternalIsRunning()
                }
            }
        }

        /// The description for the current connection status.
        /// When the status is `connected` this description will also show the time lapsed since connection.
        ///
        @Published var timeLapsed = UserText.networkProtectionStatusViewTimerZero

        private func refreshTimeLapsed() {
            switch connectionStatus {
            case .connected(let connectedDate, _):
                timeLapsed = timeLapsedString(since: connectedDate)
            case .disconnecting(let connectedDate, _):
                timeLapsed = timeLapsedString(since: connectedDate)
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
            case .connecting:
                return UserText.networkProtectionStatusConnecting
            case .disconnected:
                return UserText.networkProtectionStatusDisconnected
            case .disconnecting:
                return UserText.networkProtectionStatusDisconnecting
            case .unknown:
                return UserText.networkProtectionStatusUnknown
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
            case .connected, .disconnecting:
                return true
            default:
                return false
            }
        }

        var serverAddress: String {
            switch connectionStatus {
            case .connected(_, let serverAddress):
                return serverAddress
            case .disconnecting(_, let serverAddress):
                return serverAddress
            default:
                return ""
            }
        }

        var serverLocation: String {
            switch connectionStatus {
            case .connected, .disconnecting:
                return "Los Angeles, United States"
            default:
                return ""
            }
        }

        // MARK: - Toggling Network Protection

        /// Start network protection.
        ///
        private func startNetworkProtection() {
            Task { @MainActor in
                do {
                    try await networkProtection.start()
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
                    try await networkProtection.stop()
                } catch {
                    logger.log(error)
                    refreshInternalIsRunning()
                }
            }
        }

        // MARK: - Feedback Sharing

        /// This method provides the standard logic for handling the user's request to share feedback about NetP.
        /// 
        func shareFeedback() {
            let feedbackFormURL = URL(string: "https://form.asana.com/?k=_wNLt6YcT5ILpQjDuW0Mxw&d=137249556945")!
            NSWorkspace.shared.open(feedbackFormURL)
        }
    }
}
