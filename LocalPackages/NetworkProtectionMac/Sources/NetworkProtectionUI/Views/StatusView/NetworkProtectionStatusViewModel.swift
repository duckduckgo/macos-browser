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

import Combine
import Common
import LoginItems
import NetworkExtension
import NetworkProtection
import ServiceManagement
import SwiftUI

/// This view can be shown from any location where we want the user to be able to interact with VPN.
/// This view shows status information about the VPN, and offers a chance to toggle it ON and OFF.
///
extension NetworkProtectionStatusView {

    /// The view model definition for ``NetworkProtectionStatusView``
    ///
    @MainActor
    public final class Model: ObservableObject {

        public enum MenuItem {
            case divider(uuid: UUID = UUID())
            case text(uuid: UUID = UUID(), icon: Image? = nil, title: String, action: () async -> Void)
            case textWithDetail(uuid: UUID = UUID(), icon: Image? = nil, title: String, detail: String, action: () async -> Void)

            public var uuid: UUID {
                switch self {
                case .divider(let uuid):
                    return uuid
                case .text(let uuid, _, _, _):
                    return uuid
                case .textWithDetail(let uuid, _, _, _, _):
                    return uuid
                }
            }
        }

        /// The NetP service.
        ///
        private let tunnelController: TunnelController

        @MainActor
        @Published
        private var connectionStatus: NetworkProtection.ConnectionStatus = .default

        /// The type of extension that's being used for NetP
        ///
        @Published
        private(set) var onboardingStatus: OnboardingStatus = .completed

        var tunnelControllerViewDisabled: Bool {
            onboardingStatus != .completed || loginItemNeedsApproval || shouldShowSubscriptionExpired
        }

        @MainActor
        @Published
        var loginItemNeedsApproval = false

        /// The NetP onboarding status publisher
        ///
        private let onboardingStatusPublisher: OnboardingStatusPublisher

        /// The NetP status reporter
        ///
        private let statusReporter: NetworkProtectionStatusReporter

        public let agentLoginItem: LoginItem?
        private let isMenuBarStatusView: Bool

        // MARK: - Extra Menu Items

        public let menuItems: () -> [MenuItem]

        // MARK: - Misc

        /// The `RunLoop` for the timer.
        ///
        private let runLoopMode: RunLoop.Mode?

        private let uiActionHandler: VPNUIActionHandling

        private let uninstallHandler: () async -> Void

        private var cancellables = Set<AnyCancellable>()

        // MARK: - Dispatch Queues

        private static let statusDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.statusDispatchQueue", qos: .userInteractive)
        private static let serverInfoDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.serverInfoDispatchQueue", qos: .userInteractive)
        private static let tunnelErrorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.tunnelErrorDispatchQueue", qos: .userInteractive)
        private static let controllerErrorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.controllerErrorDispatchQueue", qos: .userInteractive)
        private static let knownFailureDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.knownFailureDispatchQueue", qos: .userInteractive)

        // MARK: - Initialization & Deinitialization

        public init(controller: TunnelController,
                    onboardingStatusPublisher: OnboardingStatusPublisher,
                    statusReporter: NetworkProtectionStatusReporter,
                    uiActionHandler: VPNUIActionHandling,
                    menuItems: @escaping () -> [MenuItem],
                    agentLoginItem: LoginItem?,
                    isMenuBarStatusView: Bool,
                    runLoopMode: RunLoop.Mode? = nil,
                    userDefaults: UserDefaults,
                    locationFormatter: VPNLocationFormatting,
                    uninstallHandler: @escaping () async -> Void) {

            self.tunnelController = controller
            self.onboardingStatusPublisher = onboardingStatusPublisher
            self.statusReporter = statusReporter
            self.menuItems = menuItems
            self.agentLoginItem = agentLoginItem
            self.isMenuBarStatusView = isMenuBarStatusView
            self.runLoopMode = runLoopMode
            self.uiActionHandler = uiActionHandler
            self.uninstallHandler = uninstallHandler

            tunnelControllerViewModel = TunnelControllerViewModel(controller: tunnelController,
                                                                  onboardingStatusPublisher: onboardingStatusPublisher,
                                                                  statusReporter: statusReporter,
                                                                  vpnSettings: .init(defaults: userDefaults),
                                                                  proxySettings: .init(defaults: userDefaults),
                                                                  locationFormatter: locationFormatter,
                                                                  uiActionHandler: uiActionHandler)

            connectionStatus = statusReporter.statusObserver.recentValue
            isHavingConnectivityIssues = statusReporter.connectivityIssuesObserver.recentValue
            lastTunnelErrorMessage = statusReporter.connectionErrorObserver.recentValue
            lastControllerErrorMessage = statusReporter.controllerErrorMessageObserver.recentValue
            knownFailure = statusReporter.knownFailureObserver.recentValue

            // Particularly useful when unit testing with an initial status of our choosing.
            subscribeToStatusChanges()
            subscribeToConnectivityIssues()
            subscribeToTunnelErrorMessages()
            subscribeToControllerErrorMessages()
            subscribeToKnownFailures()
            refreshLoginItemStatus()

            onboardingStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                self?.onboardingStatus = status
            }
            .store(in: &cancellables)

            userDefaults
                .publisher(for: \.networkProtectionEntitlementsExpired)
                .receive(on: DispatchQueue.main)
                .assign(to: \.shouldShowSubscriptionExpired, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        func refreshLoginItemStatus() {
            self.loginItemNeedsApproval = agentLoginItem?.status == .requiresApproval
        }

        func openLoginItemSettings() {
            if #available(macOS 13.0, *) {
                SMAppService.openSystemSettingsLoginItems()
            } else {
                let loginItemsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
                NSWorkspace.shared.open(loginItemsURL)
            }
        }

        func openPrivacyPro() {
            Task {
                await uiActionHandler.showPrivacyPro()
            }
        }

        func openFeedbackForm() {
            Task {
                await uiActionHandler.shareFeedback()
            }
        }

        func uninstallVPN() {
            Task {
                await uninstallHandler()
            }
        }

        private func subscribeToStatusChanges() {
            statusReporter.statusObserver.publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.connectionStatus, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        private func subscribeToConnectivityIssues() {
            statusReporter.connectivityIssuesObserver.publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.isHavingConnectivityIssues, onWeaklyHeld: self)
                .store(in: &cancellables)
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

        private func subscribeToKnownFailures() {
            statusReporter.knownFailureObserver.publisher
                .removeDuplicates()
                .subscribe(on: Self.knownFailureDispatchQueue)
                .assign(to: \.knownFailure, onWeaklyHeld: self)
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
            // We won't show any error if the connection is up.
            if case .connected = connectionStatus {
                return nil
            }

            if isHavingConnectivityIssues {
                switch connectionStatus {
                case .reasserting, .connecting, .connected:
                    return UserText.networkProtectionInterruptedReconnecting
                case .disconnecting, .disconnected:
                    return UserText.networkProtectionInterrupted
                default:
                    break
                }
            }

            if let lastControllerErrorMessage {
                return lastControllerErrorMessage
            }

            if let lastTunnelErrorMessage {
                return lastTunnelErrorMessage
            }

            return nil
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

        @Published
        var shouldShowSubscriptionExpired: Bool = false

        var promptActionViewModel: PromptActionView.Model? {
#if !APPSTORE && !DEBUG
            guard Bundle.main.isInApplicationDirectory else {
                return PromptActionView.Model(presentationData: MoveToApplicationsPromptPresentationData()) { [weak self] in
                    self?.tunnelControllerViewModel.moveToApplications()
                }
            }
#endif

            guard !loginItemNeedsApproval else {
                return PromptActionView.Model(presentationData: LoginItemsPromptPresentationData()) { [weak self] in
                    self?.openLoginItemSettings()
                }
            }

            switch onboardingStatus {
            case .completed:
                return nil
            case .isOnboarding(let step):
                switch step {

                case .userNeedsToAllowExtension, .userNeedsToAllowVPNConfiguration:
                    return PromptActionView.Model(onboardingStep: step, isMenuBar: self.isMenuBarStatusView) { [weak self] in
                        self?.tunnelControllerViewModel.startNetworkProtection()
                    }
                }

            }
        }

        @Published
        private var knownFailure: KnownFailure?

        var warningViewModel: WarningView.Model? {
            if let warningMessage = warningMessage(for: knownFailure) {
                return WarningView.Model(message: warningMessage,
                                         actionTitle: UserText.vpnSendFeedback,
                                         action: openFeedbackForm)
            }

            if let issueDescription {
                return WarningView.Model(message: issueDescription, actionTitle: nil, action: nil)
            }

            return nil
        }

        func warningMessage(for knownFailure: KnownFailure?) -> String? {
            guard let knownFailure else { return nil }

            switch KnownFailure.SilentError(rawValue: knownFailure.error) {
            case .operationNotPermitted:
                return UserText.vpnOperationNotPermittedMessage
            case .loginItemVersionMismatched:
                return UserText.vpnLoginItemVersionMismatchedMessage
            case .registeredServerFetchingFailed:
                return UserText.vpnRegisteredServerFetchingFailedMessage
            default:
                return nil
            }
        }
    }
}
