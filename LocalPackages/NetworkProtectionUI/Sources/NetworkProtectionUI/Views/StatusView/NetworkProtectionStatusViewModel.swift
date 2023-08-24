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
    @MainActor
    public final class Model: ObservableObject {

        public struct MenuItem {
            let name: String
            let action: () async -> Void

            public init(name: String, action: @escaping () async -> Void) {
                self.name = name
                self.action = action
            }
        }

        /// The NetP service.
        ///
        private let tunnelController: TunnelController

        @MainActor
        @Published
        private var connectionStatus: NetworkProtection.ConnectionStatus = .disconnected

        /// The type of extension that's being used for NetP
        ///
        @Published
        private(set) var onboardingStatus: OnboardingStatus = .completed

        var tunnelControllerViewDisabled: Bool {
            onboardingStatus != .completed
        }

        /// The NetP onboarding status publisher
        ///
        private let onboardingStatusPublisher: OnboardingStatusPublisher

        /// The NetP status reporter
        ///
        private let statusReporter: NetworkProtectionStatusReporter

        // MARK: - Extra Menu Items

        public let menuItems: [MenuItem]

        // MARK: - Misc

        /// The `RunLoop` for the timer.
        ///
        private let runLoopMode: RunLoop.Mode?

        private var cancellables = Set<AnyCancellable>()

        // MARK: - Dispatch Queues

        private static let statusDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.statusDispatchQueue", qos: .userInteractive)
        private static let connectivityIssuesDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.connectivityIssuesDispatchQueue", qos: .userInteractive)
        private static let serverInfoDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.serverInfoDispatchQueue", qos: .userInteractive)
        private static let tunnelErrorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.tunnelErrorDispatchQueue", qos: .userInteractive)
        private static let controllerErrorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.controllerErrorDispatchQueue", qos: .userInteractive)

        // MARK: - Initialization & Deinitialization

        public init(controller: TunnelController,
                    onboardingStatusPublisher: OnboardingStatusPublisher,
                    statusReporter: NetworkProtectionStatusReporter,
                    menuItems: [MenuItem],
                    runLoopMode: RunLoop.Mode? = nil) {

            self.tunnelController = controller
            self.onboardingStatusPublisher = onboardingStatusPublisher
            self.statusReporter = statusReporter
            self.menuItems = menuItems
            self.runLoopMode = runLoopMode

            tunnelControllerViewModel = TunnelControllerViewModel(controller: tunnelController,
                                                                  onboardingStatusPublisher: onboardingStatusPublisher,
                                                                  statusReporter: statusReporter)

            connectionStatus = statusReporter.statusObserver.recentValue
            isHavingConnectivityIssues = statusReporter.connectivityIssuesObserver.recentValue
            lastTunnelErrorMessage = statusReporter.connectionErrorObserver.recentValue
            lastControllerErrorMessage = statusReporter.controllerErrorMessageObserver.recentValue
            onboardingStatus = onboardingStatusPublisher.value

            // Particularly useful when unit testing with an initial status of our choosing.
            subscribeToConnectivityIssues()
            subscribeToTunnelErrorMessages()
            subscribeToControllerErrorMessages()
            subscribeToOnboardingStatusChanges()
        }

        private func subscribeToConnectivityIssues() {
            statusReporter.connectivityIssuesObserver.publisher
                .subscribe(on: Self.connectivityIssuesDispatchQueue)
                .sink { [weak self] isHavingConnectivityIssues in

                guard let self else {
                    return
                }

                Task { @MainActor in
                    self.isHavingConnectivityIssues = isHavingConnectivityIssues
                }
            }.store(in: &cancellables)
        }

        private func subscribeToTunnelErrorMessages() {
            statusReporter.connectionErrorObserver.publisher
                .subscribe(on: Self.tunnelErrorDispatchQueue)
                .sink { [weak self] errorMessage in

                guard let self else {
                    return
                }

                Task { @MainActor in
                    self.lastTunnelErrorMessage = errorMessage
                }
            }.store(in: &cancellables)
        }

        private func subscribeToControllerErrorMessages() {
            statusReporter.controllerErrorMessageObserver.publisher
                .subscribe(on: Self.controllerErrorDispatchQueue)
                .sink { [weak self] errorMessage in

                guard let self else {
                    return
                }

                Task { @MainActor in
                    self.lastControllerErrorMessage = errorMessage
                }
            }.store(in: &cancellables)
        }

        private func subscribeToOnboardingStatusChanges() {
            onboardingStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                self?.onboardingStatus = status
            }
            .store(in: &cancellables)
        }

        // MARK: - Connection Status: Errors

        @Published
        private var isHavingConnectivityIssues: Bool = false

        @Published
        private var lastControllerErrorMessage: String?

        @Published
        private var lastTunnelErrorMessage: String?

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

        // MARK: - Child View Models

        let tunnelControllerViewModel: TunnelControllerViewModel

        var onboardingStepViewModel: OnboardingStepView.Model? {
            switch onboardingStatus {
            case .completed:
                return nil
            case .isOnboarding(let step):
                return OnboardingStepView.Model(step: step) { [weak self] in
                    self?.tunnelControllerViewModel.startNetworkProtection()
                }
            }
        }
    }
}
